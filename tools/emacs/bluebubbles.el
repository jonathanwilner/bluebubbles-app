;;; bluebubbles.el --- Emacs interface for the BlueBubbles server -*- lexical-binding: t; -*-

;; Author: BlueBubbles contributors
;; Maintainer: BlueBubbles contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: communication, convenience
;; Homepage: https://github.com/BlueBubblesApp/bluebubbles-app

;; Copyright (c) 2024
;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; This file provides an Emacs client that talks to a BlueBubbles server
;; instance.  The implementation is designed around the public Flutter
;; application's network surface area, exposing every REST endpoint the
;; mobile/desktop clients use as an interactive Emacs command.  The
;; client performs the following:
;;
;;  - Auto-configures the server origin and password and attempts to
;;    authenticate on demand.  Logging only occurs if the handshake
;;    fails.
;;  - Wraps every documented REST endpoint in an interactive command
;;    reachable from `M-x` ("meta commands" in Emacs parlance).
;;  - Implements a polling loop that fetches new messages and raises
;;    notifications using either `notifications-notify` (DBus) or
;;    `message` as a fallback.
;;  - Provides helpers for sending, reacting to, editing, and unsending
;;    messages.
;;  - Supplies a transient command dispatcher for quickly invoking any
;;    API action.
;;
;; Usage:
;;
;;  (require 'bluebubbles)
;;  (bluebubbles-login)                 ; optional, happens automatically
;;  (bluebubbles-start-notifications)   ; begin polling for new messages
;;  (bluebubbles-dispatch)              ; pick any API call interactively
;;
;; The client depends on the built-in `url` library.  When available, it
;; will also use the optional `request` package for better asynchronous
;; handling.  Payloads and responses are encoded/decoded as JSON.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'url)
(require 'url-http)

(eval-when-compile
  (require 'rx))

(declare-function request "request")
(declare-function request-response-data "request")
(declare-function notifications-notify "notifications")
(declare-function dbus-ping "dbus")

(defgroup bluebubbles nil
  "BlueBubbles server integration."
  :group 'external
  :prefix "bluebubbles-")

(defcustom bluebubbles-base-url "https://imessage.thewilners.com"
  "Base URL of the BlueBubbles server instance."
  :type 'string)

(defcustom bluebubbles-api-prefix "/api/v1"
  "Prefix that precedes every API path."
  :type 'string)

(defcustom bluebubbles-guid "Platypus94022$"
  "Server password (a.k.a. GUID) used to authenticate every request."
  :type 'string)

(defcustom bluebubbles-notification-method 'auto
  "How message notifications should be presented.
When `auto`, use DBus notifications when available, falling back to
`message`.  When set to `mini-buffer`, always use `message`."
  :type '(choice (const :tag "Auto" auto)
                 (const :tag "Mini-buffer" mini-buffer)))

(defcustom bluebubbles-poll-interval 10
  "Interval in seconds between message polling rounds."
  :type 'number)

(defcustom bluebubbles-log-buffer "*BlueBubbles*"
  "Name of the buffer used for verbose API logging."
  :type 'string)

(defvar bluebubbles--last-message-timestamp nil
  "Timestamp (epoch milliseconds) for the newest message we have seen.")

(defvar bluebubbles--poll-timer nil
  "Timer object used to poll for new messages.")

(defvar bluebubbles--json-null (make-symbol "bluebubbles-json-null"))

(defun bluebubbles--log (fmt &rest args)
  "Log a message to `bluebubbles-log-buffer` using FMT and ARGS.
Logging only occurs when something unexpected happens (e.g. failed
handshakes)."
  (with-current-buffer (get-buffer-create bluebubbles-log-buffer)
    (goto-char (point-max))
    (insert (apply #'format (concat (current-time-string) " " fmt "\n") args))))

(defun bluebubbles--build-url (path &optional params options)
  "Construct a fully-qualified URL for PATH with query PARAMS.
OPTIONS may contain `:absolute`, `:no-prefix`, or `:skip-guid`.  When
`:absolute` is non-nil, PATH is treated as a fully-qualified URL and no
additional prefix or query parameters are appended."
  (let* ((absolute (plist-get options :absolute))
         (no-prefix (plist-get options :no-prefix))
         (skip-guid (plist-get options :skip-guid))
         (base (string-remove-suffix "/" bluebubbles-base-url))
         (prefix (if no-prefix "" bluebubbles-api-prefix))
         (full (cond
                (absolute path)
                ((string-prefix-p "http" path) path)
                (t (concat base prefix
                           (if (string-prefix-p "/" path)
                               path
                             (concat "/" path))))))
         (query (if (or absolute skip-guid (string-prefix-p "http" path))
                    params
                  (append params (list (cons "guid" bluebubbles-guid)))))
         (encoded (mapconcat (lambda (pair)
                               (when (and (cdr pair)
                                          (not (string-empty-p (format "%s" (cdr pair)))))
                                 (concat (url-hexify-string (car pair))
                                         "="
                                         (url-hexify-string (format "%s" (cdr pair))))))
                             query
                             "&")))
    (if (string-empty-p encoded)
        full
      (concat full "?" encoded)))

(defun bluebubbles--ensure-string (value)
  "Return VALUE as a string."
  (cond
   ((null value) "")
   ((eq value t) "true")
   ((eq value json-false) "false")
   ((stringp value) value)
   (t (format "%s" value))))

(defun bluebubbles--json-clean (payload)
  "Replace `bluebubbles--json-null` markers with JSON null in PAYLOAD."
  (cond
   ((eq payload bluebubbles--json-null) :json-null)
   ((listp payload)
    (mapcar #'bluebubbles--json-clean payload))
   ((vectorp payload)
    (cl-map 'vector #'bluebubbles--json-clean payload))
   ((consp payload)
    (cons (car payload) (bluebubbles--json-clean (cdr payload))))
   (t payload)))

(defun bluebubbles--mime-type (filename)
  "Infer a MIME type for FILENAME."
  (or (when (require 'mailcap nil t)
        (let* ((extension (file-name-extension filename))
               (lower (and extension (downcase extension))))
          (and lower (mailcap-extension-to-mime lower))))
      "application/octet-stream"))

(defun bluebubbles--read-file-bytes (file)
  "Return the literal byte contents of FILE as a unibyte string."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (buffer-string)))

(defun bluebubbles--encode-multipart (parts boundary)
  "Assemble PARTS into a multipart/form-data payload using BOUNDARY.
Each entry in PARTS is a plist with :name, :data, and optional :filename
and :type keys."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (dolist (part parts)
      (let ((name (plist-get part :name))
            (data (plist-get part :data))
            (filename (plist-get part :filename))
            (type (or (plist-get part :type) "application/octet-stream")))
        (insert "--" boundary "\r\n")
        (insert "Content-Disposition: form-data; name=\"" name "\"")
        (when filename
          (insert "; filename=\"" filename "\"\r\n")
          (insert "Content-Type: " type "\r\n"))
        (insert "\r\n")
        (when data
          (insert (if (multibyte-string-p data)
                      (encode-coding-string data 'utf-8)
                    data)))
        (insert "\r\n")))
    (insert "--" boundary "--\r\n")
    (buffer-string)))

(defun bluebubbles--multipart-boundary ()
  "Return a unique multipart/form-data boundary string."
  (format "---------------------------bluebubbles-%s"
          (md5 (format "%s-%s-%s" (float-time) (random) (user-uid)))))

(defun bluebubbles--http-request (method path &optional params data options)
  "Perform an HTTP request using METHOD to PATH.
PARAMS is an alist of query parameters, DATA is an alist to be encoded as
JSON (unless already a string), and HEADERS extends the default header
set.  Returns an alist parsed from JSON or signals an error."
  (let* ((headers (plist-get options :headers))
         (absolute (plist-get options :absolute))
         (no-prefix (plist-get options :no-prefix))
         (skip-guid (plist-get options :skip-guid))
         (multipart (plist-get options :multipart))
         (boundary (when multipart (bluebubbles--multipart-boundary)))
         (url-request-method (upcase (bluebubbles--ensure-string method)))
         (url (bluebubbles--build-url path params
                                      (list :absolute absolute
                                            :no-prefix no-prefix
                                            :skip-guid skip-guid)))
         (default-headers (unless multipart
                            '(("Content-Type" . "application/json"))))
         (url-request-extra-headers (append headers
                                             (when multipart
                                               (list (cons "Content-Type"
                                                          (format "multipart/form-data; boundary=%s"
                                                                  boundary))))
                                             default-headers))
         (url-request-data (cond
                            (multipart
                             (bluebubbles--encode-multipart multipart boundary))
                            (data
                             (if (stringp data)
                                 data
                               (encode-coding-string
                                (json-encode (bluebubbles--json-clean data))
                                'utf-8))))))
    (condition-case err
        (if (featurep 'request)
            (let* ((response (request url
                                      :type url-request-method
                                      :data url-request-data
                                      :headers url-request-extra-headers
                                      :parser (lambda ()
                                                (let ((json-object-type 'alist)
                                                      (json-array-type 'vector)
                                                      (json-key-type 'string))
                                                  (condition-case parse-err
                                                      (json-read)
                                                    (error
                                                     (bluebubbles--log "JSON parse error: %s" parse-err)
                                                     nil))))
                                      :sync t))
                   (data (when response (request-response-data response))))
              (or data (bluebubbles--log "Empty response for %s %s" method path)
                  nil))
          (with-current-buffer (url-retrieve-synchronously url t)
            (unwind-protect
                (progn
                  (goto-char url-http-end-of-headers)
                  (let ((json-object-type 'alist)
                        (json-array-type 'vector)
                        (json-key-type 'string))
                    (condition-case parse-err
                        (json-read)
                      (error
                       (bluebubbles--log "JSON parse error: %s" parse-err)
                       nil))))
              (kill-buffer (current-buffer)))))
      (error
       (bluebubbles--log "Request failed: %s" err)
       (signal (car err) (cdr err))))))

(defun bluebubbles--call (method path &optional params body &rest options)
  "Wrapper around `bluebubbles--http-request`.
METHOD, PATH, PARAMS, BODY, and PLIST are forwarded directly.  When the
request fails or returns an error, the function raises a meaningful
signal."
  (let* ((response (bluebubbles--http-request method path params body options))
         (ok (alist-get "success" response)))
    (if (or (null response) (eq ok json-false))
        (let ((message (or (alist-get "message" response)
                           (alist-get "error" response)
                           "Unknown BlueBubbles API failure")))
          (bluebubbles--log "API failure for %s %s: %s" method path message)
          (error "%s" message))
      response))

;;;###autoload
(defun bluebubbles-login ()
  "Attempt to contact the server and cache the last-seen message.
The function only emits output when the handshake fails."
  (interactive)
  (condition-case err
      (let* ((info (bluebubbles--call "GET" "/server/info"))
             (messages (bluebubbles--call "POST" "/message/query" nil
                                         `(("limit" . 1)
                                           ("offset" . 0)
                                           ("sort" . "DESC")
                                           ("with" . ["chat" "handle"]))))
             (rows (alist-get "data" messages))
             (latest (and (vectorp rows)
                          (> (length rows) 0)
                          (aref rows 0)))
             (timestamp (alist-get "dateCreated" latest)))
        (setq bluebubbles--last-message-timestamp timestamp)
        (setq bluebubbles--server-info info)
        info)
    (error
     (bluebubbles--log "Login failed: %s" err)
     (signal (car err) (cdr err)))))

(defvar bluebubbles--server-info nil
  "Latest result from `/server/info`.  Populated on login.")

(defun bluebubbles--ensure-login ()
  "Ensure that the client has successfully talked to the server."
  (unless bluebubbles--server-info
    (bluebubbles-login)))

(defun bluebubbles--prompt (prompt &optional initial required)
  "Read a string from the minibuffer using PROMPT.
When REQUIRED is non-nil the function will continue prompting until a
non-empty response is supplied."
  (let ((prompt-text (concat prompt (if required " (required): " ": ")))
        (value nil)
        (current initial))
    (while (or (null value)
               (and required (string-empty-p value)))
      (setq value (read-string prompt-text current))
      (setq current nil))
    value))

(defun bluebubbles--prompt-json (prompt)
  "Read a JSON payload from the minibuffer using PROMPT.
Returns an alist after parsing."
  (let* ((raw (read-string (concat prompt " (JSON, empty for {})": ) ""))
         (trimmed (string-trim raw)))
    (if (string-empty-p trimmed)
        nil
      (json-read-from-string trimmed)))

(defun bluebubbles--notify (title body)
  "Display a desktop notification (or fall back to `message`)."
  (pcase bluebubbles-notification-method
    ('mini-buffer (message "%s: %s" title body))
    ('auto (if (and (fboundp 'notifications-notify)
                    (fboundp 'dbus-ping)
                    (dbus-ping :session "org.freedesktop.Notifications"))
               (notifications-notify :title title :body body)
             (message "%s: %s" title body)))
    (_ (message "%s: %s" title body))))

(defun bluebubbles--extract-timestamp (message)
  "Extract an integer timestamp from MESSAGE alist."
  (let ((value (or (alist-get "dateCreated" message)
                   (alist-get "date" message))))
    (cond
     ((numberp value) value)
     ((stringp value)
      (condition-case nil
          (string-to-number value)
        (error 0)))
     (t 0))))

(defun bluebubbles--format-message (message)
  "Format MESSAGE alist into a human-readable string."
  (let* ((text (or (alist-get "text" message)
                   (alist-get "message" message)
                   ""))
         (chat (alist-get "chat" message))
         (chat-title (or (alist-get "displayName" chat)
                         (alist-get "guid" chat) ""))
         (handle (alist-get "handle" message))
         (sender (or (alist-get "displayName" handle)
                     (alist-get "address" handle)
                     "Unknown")))
    (format "%s (%s): %s" sender chat-title text)))

(defun bluebubbles--poll-once ()
  "Fetch new messages and display notifications."
  (condition-case err
      (progn
        (bluebubbles--ensure-login)
        (let* ((params `(("limit" . 50)
                         ("offset" . 0)
                         ("sort" . "DESC")
                         ("with" . ["chat" "handle"])) )
               (after bluebubbles--last-message-timestamp))
          (when (and after (> after 0))
            (setq params (append params `(("after" . ,after)))))
          (let* ((response (bluebubbles--call "POST" "/message/query" nil params))
                 (rows (alist-get "data" response)))
            (when (and (vectorp rows) (> (length rows) 0))
              (cl-loop for message across rows
                       for timestamp = (bluebubbles--extract-timestamp message)
                       do (when (and timestamp
                                     (or (null bluebubbles--last-message-timestamp)
                                         (> timestamp bluebubbles--last-message-timestamp)))
                            (setq bluebubbles--last-message-timestamp timestamp)
                            (bluebubbles--notify "BlueBubbles" (bluebubbles--format-message message))))))))
    (error
     (bluebubbles--log "Polling error: %s" err))))

;;;###autoload
(defun bluebubbles-start-notifications ()
  "Start polling the server for new messages and raise notifications."
  (interactive)
  (bluebubbles--ensure-login)
  (unless (timerp bluebubbles--poll-timer)
    (setq bluebubbles--poll-timer
          (run-at-time bluebubbles-poll-interval bluebubbles-poll-interval
                       #'bluebubbles--poll-once)))
  (message "BlueBubbles notifications enabled."))

;;;###autoload
(defun bluebubbles-stop-notifications ()
  "Stop the message polling timer."
  (interactive)
  (when (timerp bluebubbles--poll-timer)
    (cancel-timer bluebubbles--poll-timer)
    (setq bluebubbles--poll-timer nil)
    (message "BlueBubbles notifications disabled.")))

;;;###autoload
(define-minor-mode bluebubbles-notifications-mode
  "Toggle BlueBubbles background notifications.
When enabled, the client polls the configured server at
`bluebubbles-poll-interval' to surface new message alerts."
  :global t
  :group 'bluebubbles
  (if bluebubbles-notifications-mode
      (bluebubbles-start-notifications)
    (bluebubbles-stop-notifications)))

(defun bluebubbles--resolve-path (template &optional raw)
  "Resolve TEMPLATE by prompting for values enclosed in braces.
When RAW is non-nil the substituted values are inserted verbatim instead
of URL-encoding them."
  (let ((result template)
        (regex (rx "{" (group (+? (not (any "}")))) "}")))
    (while (string-match regex result)
      (let* ((placeholder (match-string 1 result))
             (value (bluebubbles--prompt (format "%s" placeholder) nil t)))
        (setq result (replace-match (if raw value (url-hexify-string value)) t t result))))
    result)

(defun bluebubbles--read-query (fields)
  "Read query parameters defined by FIELDS.
FIELDS is a list of cons cells (NAME . REQUIRED?)."
  (when fields
    (cl-remove-if-not #'cdr
                      (mapcar (lambda (entry)
                                (let* ((name (car entry))
                                       (required (cdr entry))
                                       (value (bluebubbles--prompt name nil required)))
                                  (when (or required (not (string-empty-p value)))
                                    (cons name value))))
                              fields))))

(defun bluebubbles--read-body (fields)
  "Read body payload described by FIELDS.
Each entry in FIELDS is (NAME TYPE REQUIRED?).  TYPE may be `string',
`number', `boolean', `json', or `file'."
  (let ((result '()))
    (dolist (field fields)
      (pcase-let ((`(,name ,type ,required) field))
        (pcase type
          ('json
           (let ((json (bluebubbles--prompt-json name)))
             (when json (push (cons name json) result))))
          ('boolean
           (let* ((answer (bluebubbles--prompt (format "%s (y/n)" name)
                                               (if required "y" "")
                                               required))
                  (value (and (not (string-empty-p answer))
                              (member (downcase answer) '("y" "yes" "t" "true")))))
             (push (cons name (if value t json-false)) result)))
          ('number
           (let* ((input (bluebubbles--prompt name nil required)))
             (when (or required (not (string-empty-p input)))
               (push (cons name (string-to-number input)) result))))
          ('file
           (let ((path (read-file-name (format "%s (file path): " name) nil nil required)))
             (when (and path (not (string-empty-p path)))
               (push (cons name (list :file path
                                      :filename (file-name-nondirectory path)
                                      :mime (bluebubbles--mime-type path)))
                     result))))
          (_
           (let ((value (bluebubbles--prompt name nil required)))
             (when (or required (not (string-empty-p value)))
               (push (cons name value) result))))))
    (nreverse result)))

;;;###autoload
(defun bluebubbles-dispatch (action-name)
  "Prompt for an ACTION-NAME and execute it."
  (interactive
   (list (completing-read "BlueBubbles action: "
                          (mapcar (lambda (entry) (alist-get :name entry))
                                  bluebubbles-api-actions)
                          nil t)))
  (let ((action (cl-find-if (lambda (entry)
                              (equal (alist-get :name entry) action-name))
                            bluebubbles-api-actions)))
    (unless action
      (error "Unknown BlueBubbles action: %s" action-name))
    (bluebubbles--run-action action)))

;;;###autoload
(defun bluebubbles-send-text (chat-guid message)
  "Send MESSAGE to CHAT-GUID using `/message/text`."
  (interactive (list (bluebubbles--prompt "Chat GUID" nil t)
                     (bluebubbles--prompt "Message" nil t)))
  (bluebubbles--ensure-login)
  (let ((response (bluebubbles--call "POST" "/message/text" nil
                                     `(("chatGuid" . ,chat-guid)
                                       ("tempGuid" . ,(format "temp-%s" (float-time)))
                                       ("message" . ,message)))))
    (message "Message sent.")
    response))

;;;###autoload
(defun bluebubbles-send-attachment (chat-guid file-path &optional name)
  "Send FILE-PATH as an attachment to CHAT-GUID."
  (interactive (list (bluebubbles--prompt "Chat GUID" nil t)
                     (read-file-name "Attachment: " nil nil t)
                     (bluebubbles--prompt "Display name (optional)")))
  (bluebubbles--ensure-login)
  (let* ((temp-guid (format "temp-%s" (float-time)))
         (filename (file-name-nondirectory file-path))
         (display (or name filename))
         (file-bytes (bluebubbles--read-file-bytes file-path))
         (response (bluebubbles--call
                    "POST" "/message/attachment" nil nil
                    :multipart (list (list :name "chatGuid" :data chat-guid)
                                     (list :name "tempGuid" :data temp-guid)
                                     (list :name "name" :data display)
                                     (list :name "attachment"
                                           :filename filename
                                           :type (bluebubbles--mime-type filename)
                                           :data file-bytes)))))
    (message "Attachment uploaded: %s" (alist-get "message" response))
    response))

;;;###autoload
(defun bluebubbles-send-quick-reply (chat-guid text)
  "Send TEXT to CHAT-GUID and display the server response."
  (interactive (list (bluebubbles--prompt "Chat GUID" nil t)
                     (bluebubbles--prompt "Message" nil t)))
  (bluebubbles--ensure-login)
  (let ((response (bluebubbles-send-text chat-guid text)))
    (message "Server response: %s" response)))

;;;###autoload
(defun bluebubbles-list-chats ()
  "Retrieve the chat list from the server."
  (interactive)
  (bluebubbles--ensure-login)
  (let ((response (bluebubbles--call "POST" "/chat/query" nil
                                     '(("limit" . 50)
                                       ("offset" . 0)
                                       ("sort" . "DESC")
                                       ("with" . ["participants" "lastMessage"])))) )
    (with-current-buffer (get-buffer-create "*BlueBubbles Chats*")
      (erase-buffer)
      (let ((rows (alist-get "data" response)))
        (if (and (vectorp rows) (> (length rows) 0))
            (cl-loop for chat across rows
                     for guid = (alist-get "guid" chat)
                     for title = (or (alist-get "displayName" chat) guid)
                     for unread = (alist-get "unreadMessageCount" chat)
                     do (insert (format "%s (%s unread)\n" title unread)))
          (insert "No chats found.")))
      (display-buffer (current-buffer)))
    response))

;;;###autoload
(defun bluebubbles-open-chat (chat-guid)
  "Fetch the latest messages for CHAT-GUID and display them."
  (interactive (list (bluebubbles--prompt "Chat GUID" nil t)))
  (bluebubbles--ensure-login)
  (let ((response (bluebubbles--call "GET"
                                     (format "/chat/%s/message" chat-guid)
                                     '(("limit" . 50)
                                       ("offset" . 0)
                                       ("sort" . "DESC")
                                       ("with" . "attachments")))))
    (with-current-buffer (get-buffer-create (format "*BlueBubbles %s*" chat-guid))
      (erase-buffer)
      (let ((rows (alist-get "data" response)))
        (if (and (vectorp rows) (> (length rows) 0))
            (cl-loop for message across rows
                     do (insert (bluebubbles--format-message message) "\n"))
          (insert "No messages.")))
      (display-buffer (current-buffer)))
    response))

;;;
;;; API action catalogue
;;;

(defconst bluebubbles-api-actions
  (let ((actions '()))
    (cl-labels ((add (name method path &optional query body notes &rest extra)
                  (let ((entry (cl-remove-if #'null
                                             (list (cons :name name)
                                                   (cons :method method)
                                                   (cons :path path)
                                                   (cons :query query)
                                                   (cons :body body)
                                                   (cons :notes notes)))))
                    (while extra
                      (let ((key (pop extra))
                            (value (pop extra)))
                        (when value
                          (push (cons key value) entry))))
                    (push entry actions))))
      ;; Server & Mac controls
      (add "server-ping" "GET" "/ping")
      (add "mac-lock" "POST" "/mac/lock")
      (add "mac-imessage-restart" "POST" "/mac/imessage/restart")
      (add "server-info" "GET" "/server/info")
      (add "server-restart-soft" "GET" "/server/restart/soft")
      (add "server-restart-hard" "GET" "/server/restart/hard")
      (add "server-update-check" "GET" "/server/update/check")
      (add "server-update-install" "POST" "/server/update/install")
      (add "server-statistics-totals" "GET" "/server/statistics/totals")
      (add "server-statistics-media" "GET" "/server/statistics/media")
      (add "server-statistics-media-chat" "GET" "/server/statistics/media/chat")
      (add "server-logs" "GET" "/server/logs" '(("count" . nil)))
      ;; Push & notification devices
      (add "fcm-device-add" "POST" "/fcm/device" nil
           '(("name" string t)
             ("identifier" string t)))
      (add "fcm-client-state" "GET" "/fcm/client")
      ;; Attachments
      (add "attachment-metadata" "GET" "/attachment/{guid}")
      (add "attachment-download" "GET" "/attachment/{guid}/download"
           '(("original" . nil)))
      (add "attachment-live" "GET" "/attachment/{guid}/live")
      (add "attachment-blurhash" "GET" "/attachment/{guid}/blurhash")
      (add "attachment-count" "GET" "/attachment/count")
      ;; Chat management
      (add "chat-query" "POST" "/chat/query" nil
           '(("with" json nil)
             ("offset" number nil)
             ("limit" number nil)
             ("sort" string nil)))
      (add "chat-messages" "GET" "/chat/{chatGuid}/message"
           '(("with" . nil)
             ("sort" . nil)
             ("before" . nil)
             ("after" . nil)
             ("offset" . nil)
             ("limit" . nil)))
      (add "chat-participant" "POST" "/chat/{chatGuid}/participant/{method}" nil
           '(("address" string t)))
      (add "chat-leave" "POST" "/chat/{chatGuid}/leave")
      (add "chat-rename" "PUT" "/chat/{chatGuid}" nil
           '(("displayName" string t)))
      (add "chat-create" "POST" "/chat/new" nil
           '(("addresses" json t)
             ("message" string nil)
             ("service" string t)
             ("method" string nil)))
      (add "chat-count" "GET" "/chat/count")
      (add "chat-get" "GET" "/chat/{chatGuid}" '(("with" . nil)))
      (add "chat-read" "POST" "/chat/{chatGuid}/read")
      (add "chat-unread" "POST" "/chat/{chatGuid}/unread")
      (add "chat-icon-get" "GET" "/chat/{chatGuid}/icon")
      (add "chat-icon-set" "POST" "/chat/{chatGuid}/icon" nil
           '(("icon" file t)))
      (add "chat-icon-delete" "DELETE" "/chat/{chatGuid}/icon")
      (add "chat-delete" "DELETE" "/chat/{chatGuid}")
      (add "chat-message-delete" "DELETE" "/chat/{chatGuid}/{messageGuid}")
      ;; Message operations
      (add "message-count" "GET" "/message/count"
           '(("after" . nil) ("before" . nil)))
      (add "message-count-updated" "GET" "/message/count/updated"
           '(("after" . nil) ("before" . nil)))
      (add "message-count-me" "GET" "/message/count/me"
           '(("after" . nil) ("before" . nil)))
      (add "message-query" "POST" "/message/query" nil
           '(("with" json nil)
             ("where" json nil)
             ("sort" string nil)
             ("before" number nil)
             ("after" number nil)
             ("chatGuid" string nil)
             ("offset" number nil)
             ("limit" number nil)
             ("convertAttachments" boolean nil)))
      (add "message-get" "GET" "/message/{guid}" '(("with" . nil)))
      (add "message-embedded-media" "GET" "/message/{guid}/embedded-media")
      (add "message-send-text" "POST" "/message/text" nil
           '(("chatGuid" string t)
             ("tempGuid" string t)
             ("message" string t)
             ("method" string nil)
             ("effectId" string nil)
             ("subject" string nil)
             ("selectedMessageGuid" string nil)
             ("partIndex" number nil)
             ("ddScan" boolean nil)))
      (add "message-send-attachment" "POST" "/message/attachment" nil
           '(("chatGuid" string t)
             ("tempGuid" string t)
             ("name" string nil)
             ("attachment" file t)
             ("method" string nil)
             ("effectId" string nil)
             ("subject" string nil)
             ("selectedMessageGuid" string nil)
             ("partIndex" number nil)
             ("isAudioMessage" boolean nil)))
      (add "message-send-multipart" "POST" "/message/multipart" nil
           '(("chatGuid" string t)
             ("tempGuid" string t)
             ("parts" json t)
             ("effectId" string nil)
             ("subject" string nil)
             ("selectedMessageGuid" string nil)
             ("partIndex" number nil)
             ("ddScan" boolean nil)))
      (add "message-react" "POST" "/message/react" nil
           '(("chatGuid" string t)
             ("selectedMessageText" string nil)
             ("selectedMessageGuid" string t)
             ("reaction" string t)
             ("partIndex" number nil)))
      (add "message-unsend" "POST" "/message/{guid}/unsend" nil
           '(("partIndex" number nil)))
      (add "message-edit" "POST" "/message/{guid}/edit" nil
           '(("editedMessage" string t)
             ("backwardsCompatibilityMessage" string nil)
             ("partIndex" number nil)))
      (add "message-notify" "POST" "/message/{guid}/notify")
      ;; Scheduled messaging
      (add "schedule-list" "GET" "/message/schedule")
      (add "schedule-create" "POST" "/message/schedule" nil
           '(("type" string t)
             ("payload" json t)
             ("scheduledFor" number t)
             ("schedule" json nil)))
      (add "schedule-update" "PUT" "/message/schedule/{id}" nil
           '(("type" string t)
             ("payload" json t)
             ("scheduledFor" number t)
             ("schedule" json nil)))
      (add "schedule-delete" "DELETE" "/message/schedule/{id}")
      ;; Handle lookups
      (add "handle-count" "GET" "/handle/count")
      (add "handle-query" "POST" "/handle/query" nil
           '(("with" json nil)
             ("address" string nil)
             ("offset" number nil)
             ("limit" number nil)))
      (add "handle-get" "GET" "/handle/{guid}")
      (add "handle-focus" "GET" "/handle/{address}/focus")
      (add "handle-availability-imessage" "GET" "/handle/availability/imessage"
           '(("address" . t)))
      (add "handle-availability-facetime" "GET" "/handle/availability/facetime"
           '(("address" . t)))
      ;; Contacts & iCloud
      (add "contact-list" "GET" "/contact" '(("extraProperties" . nil)))
      (add "contact-lookup" "POST" "/contact/query" nil
           '(("addresses" json t)))
      (add "contact-create" "POST" "/contact" nil
           '(("contacts" json t)))
      (add "icloud-account" "GET" "/icloud/account")
      (add "icloud-contact" "GET" "/icloud/contact")
      (add "icloud-alias-set" "POST" "/icloud/account/alias" nil
           '(("alias" string t)))
      ;; Backups
      (add "backup-theme-get" "GET" "/backup/theme")
      (add "backup-theme-save" "POST" "/backup/theme" nil
           '(("name" string t)
             ("data" json t)))
      (add "backup-theme-delete" "DELETE" "/backup/theme" nil
           '(("name" string t)))
      (add "backup-settings-get" "GET" "/backup/settings")
      (add "backup-settings-delete" "DELETE" "/backup/settings" nil
           '(("name" string t)))
      (add "backup-settings-save" "POST" "/backup/settings" nil
           '(("name" string t)
             ("data" json t)))
      ;; FaceTime control
      (add "facetime-answer" "POST" "/facetime/answer/{callUuid}")
      (add "facetime-leave" "POST" "/facetime/leave/{callUuid}")
      ;; Find My
      (add "findmy-devices" "GET" "/icloud/findmy/devices")
      (add "findmy-devices-refresh" "POST" "/icloud/findmy/devices/refresh")
      (add "findmy-friends" "GET" "/icloud/findmy/friends")
      (add "findmy-friends-refresh" "POST" "/icloud/findmy/friends/refresh")
      ;; Utility
      (add "landing-page" "GET" "/" nil nil nil :no-prefix t)
      (add "download-from-url" "GET" "{url}" nil nil nil :raw-path t)
      ;; Firebase / Google helpers
      (add "firebase-projects" "GET" "https://firebase.googleapis.com/v1beta1/projects"
           '(("access_token" . t)))
      (add "google-userinfo" "GET" "https://www.googleapis.com/oauth2/v1/userinfo"
           '(("access_token" . t)))
      (add "firebase-rtdb-config" "GET" "https://{rtdb}.firebaseio.com/config.json"
           '(("token" . t)))
      (add "firestore-server-config" "GET" "https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/server/config"
           '(("access_token" . t)))
      (add "firestore-restart" "PATCH" "https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/server/commands"
           '(("updateMask.fieldPaths" . t))
           '(("fields" json t)))
      ;; Socket helpers (meta commands only)
      (add "socket-started-typing" "SOCKET" "started-typing" nil
           '(("chatGuid" string t)))
      (add "socket-stopped-typing" "SOCKET" "stopped-typing" nil
           '(("chatGuid" string t)))
      (nreverse actions)))
  "List of BlueBubbles API actions with prompt metadata.")

(defun bluebubbles--socket-emit (event payload)
  "Emit EVENT with PAYLOAD via Socket.IO.
This implementation uses the HTTP fallback because establishing a true
Socket.IO connection from Emacs Lisp is beyond the scope of this client.
Instead, we call the corresponding REST endpoints when available.  For
actions that are socket-only, log a message."
  (bluebubbles--log "Socket emit %s %s" event payload)
  (message "Socket emit %s queued (no-op)." event))

(defun bluebubbles--run-action (action)
  "Execute ACTION specification from `bluebubbles-api-actions'."
  (bluebubbles--ensure-login)
  (pcase-let* ((`((:name . ,name)
                  (:method . ,method)
                  (:path . ,path)
                  (:query . ,query)
                  (:body . ,body)
                  (:absolute . ,absolute)
                  (:no-prefix . ,no-prefix)
                  (:skip-guid . ,skip-guid)
                  (:raw-path . ,raw-path)) action))
    (cond
     ((string= method "SOCKET")
      (let* ((payload (bluebubbles--read-body body)))
        (bluebubbles--socket-emit path payload)))
     (t
      (let* ((resolved-path (bluebubbles--resolve-path path raw-path))
             (query-params (bluebubbles--read-query query))
             (payload (bluebubbles--read-body body))
             (has-file (cl-some (lambda (entry)
                                  (let ((value (cdr entry)))
                                    (and (listp value)
                                         (plist-get value :file))))
                                payload))
             (options (append (when absolute (list :absolute t))
                              (when no-prefix (list :no-prefix t))
                              (when skip-guid (list :skip-guid t))))
             (response (if has-file
                           (let ((multipart (mapcar
                                             (lambda (entry)
                                               (let* ((name (car entry))
                                                      (value (cdr entry)))
                                                 (if (and (listp value) (plist-get value :file))
                                                     (list :name name
                                                           :filename (plist-get value :filename)
                                                           :type (or (plist-get value :mime)
                                                                     "application/octet-stream")
                                                           :data (bluebubbles--read-file-bytes (plist-get value :file)))
                                                   (list :name name
                                                         :data (bluebubbles--ensure-string value)))))
                                             payload)))
                             (apply #'bluebubbles--call method resolved-path query-params nil
                                    (append options (list :multipart multipart))))
                         (apply #'bluebubbles--call method resolved-path query-params payload
                                options))))
        (with-current-buffer (get-buffer-create bluebubbles-log-buffer)
          (goto-char (point-max))
          (insert (format "\n=== %s (%s %s) ===\n" name method resolved-path))
          (insert (json-encode response) "\n"))
        (message "%s: success" name)
        response)))))

(provide 'bluebubbles)

;;; bluebubbles.el ends here
