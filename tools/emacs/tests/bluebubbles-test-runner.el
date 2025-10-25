;;; bluebubbles-test-runner.el --- Run bluebubbles ERT suite -*- lexical-binding: t; -*-

(require 'ert)
(add-to-list 'load-path (file-name-directory (directory-file-name (file-name-directory load-file-name))))
(add-to-list 'load-path (file-name-directory load-file-name))

(require 'bluebubbles-test)

(ert-run-tests-batch-and-exit)

;;; bluebubbles-test-runner.el ends here
