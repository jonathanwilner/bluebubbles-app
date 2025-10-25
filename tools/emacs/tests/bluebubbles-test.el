;;; bluebubbles-test.el --- Tests for bluebubbles.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'bluebubbles)

(ert-deftest bluebubbles-build-url-adds-guid ()
  (let ((bluebubbles-base-url "https://example.com")
        (bluebubbles-api-prefix "/api/v1")
        (bluebubbles-guid "secret"))
    (should (string=
             (bluebubbles--build-url "/message/text")
             "https://example.com/api/v1/message/text?guid=secret"))))

(ert-deftest bluebubbles-build-url-supports-options ()
  (let ((bluebubbles-base-url "https://example.com/")
        (bluebubbles-api-prefix "/api/v1")
        (bluebubbles-guid "secret"))
    (should (string=
             (bluebubbles--build-url "https://other.test/resource" nil (list :absolute t))
             "https://other.test/resource"))
    (should (string=
             (bluebubbles--build-url "/status" nil (list :skip-guid t))
             "https://example.com/api/v1/status"))
    (should (string=
             (bluebubbles--build-url "status" nil (list :no-prefix t))
             "https://example.com/status?guid=secret"))))

(ert-deftest bluebubbles-json-clean-replaces-markers ()
  (let ((input `(foo ,bluebubbles--json-null (bar . ,bluebubbles--json-null))))
    (should (equal (bluebubbles--json-clean input)
                   '(foo :json-null (bar . :json-null))))))

(ert-deftest bluebubbles-multipart-encoding ()
  (let* ((boundary (bluebubbles--multipart-boundary))
         (payload (bluebubbles--encode-multipart
                   (list (list :name "chatGuid" :data "GUID")
                         (list :name "attachment" :filename "file.txt" :type "text/plain" :data "hi"))
                   boundary)))
    (should (string-match (concat "--" boundary) payload))
    (should (string-match "Content-Disposition: form-data; name=\"attachment\"; filename=\"file.txt\"" payload))
    (should (string-match "Content-Type: text/plain" payload))
    (should (string-suffix-p (concat "--" boundary "--\r\n") payload))))

(ert-deftest bluebubbles-send-attachment-builds-multipart ()
  (let ((bluebubbles--server-info t)
        (captured nil))
    (cl-letf* (((symbol-function 'bluebubbles--ensure-login) #'ignore)
               ((symbol-function 'bluebubbles--read-file-bytes)
                 (lambda (_file) "DATA"))
               ((symbol-function 'bluebubbles--call)
                 (lambda (_method _path _params _body &rest options)
                   (setq captured options)
                   '(("success" . t) ("message" . "ok")))))
      (bluebubbles-send-attachment "chat" "/tmp/file.txt" "pretty")
      (let ((multipart (plist-get captured :multipart)))
        (should multipart)
        (should (= 4 (length multipart)))
        (should (equal (plist-get (nth 0 multipart) :data) "chat"))
        (should (equal (plist-get (nth 2 multipart) :data) "pretty"))
        (let ((file-part (nth 3 multipart)))
          (should (equal (plist-get file-part :filename) "file.txt"))
          (should (equal (plist-get file-part :data) "DATA")))))))

(provide 'bluebubbles-test)
;;; bluebubbles-test.el ends here
