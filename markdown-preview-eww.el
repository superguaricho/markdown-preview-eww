;;; markdown-preview-eww.el --- Realtime preview by eww -*- lexical-binding: t; -*-

;; Copyright (c) 2014, 2015, 2016 niku

;; Author: niku <niku@niku.name>
;; URL: https://github.com/niku/markdown-preview-eww
;; Package-Version: 20160111.1502
;; Package-Revision: 5853f836425c
;; Package-Requires: ((emacs "24.4"))


;; This file is not part of GNU Emacs.

;; The MIT License (MIT)

;; Permission is hereby granted, free of charge, to any person obtaining a copy of
;; this software and associated documentation files (the "Software"), to deal in
;; the Software without restriction, including without limitation the rights to
;; use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
;; the Software, and to permit persons to whom the Software is furnished to do so,
;; subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
;; FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
;; COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
;; IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Commentary:

;; This package provides the realtime markdown preview by eww.

;;; Code:
(defvar markdown-preview-eww-process-name "convert-from-md-to-html"
  "Process name of a converter.")

(defvar-local markdown-preview-eww--output-file nil
  "The absolute path to the temporary output file for this buffer.")

(defvar markdown-preview-eww-waiting-idling-second 1
  "Seconds of convert waiting")

(defun markdown-preview-eww-convert-command (output-file-name)
  (message "Generating convert command for output file: %s" output-file-name)
  (format "$stderr.reopen($stdout)
require \"redcarpet\"

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
while doc = gets(\"\\0\")
  doc.chomp!(\"\\0\")
  File.write(\"%s\", markdown.render(doc))
end" output-file-name))

(add-to-list 'exec-path "/home/numa/.rbenv/bin/")
(add-to-list 'exec-path
             (file-name-directory
              (string-trim-right
               (shell-command-to-string
                (format "%s which ruby" (executable-find "rbenv"))))))

(defun markdown-preview-eww--do-convert (ofile markdown-preview-mdbuf)
  (let* ((doc (with-current-buffer markdown-preview-mdbuf
                (buffer-substring-no-properties (point-min) (point-max)))))
    (message "Idle timer fired for markdown to HTML conversion.")
    (message "Output file: %s" ofile)
    (or (get-process markdown-preview-eww-process-name)
        (error "No conversion process"))
    (if (and ofile (get-process markdown-preview-eww-process-name))
        (progn (message "Converting markdown to HTML...")
               (process-send-string
                (get-process markdown-preview-eww-process-name)
                (concat doc "\0"))
               (eww-open-file ofile)
               (kill-process
                (get-process markdown-preview-eww-process-name)))
      (message "No output file or conversion process found."))))

;;;### autoload
(defun markdown-preview-eww ()
  "Start a realtime markdown preview."
  (interactive)
  (when (executable-find "ruby")
    (let* ((process-connection-type nil)
           (output-file (make-temp-file "markdown-preview-" nil ".html"))
           (convert-command (markdown-preview-eww-convert-command output-file))
           (preview-buf (current-buffer)))
      (start-process markdown-preview-eww-process-name
                     nil
                     (executable-find "ruby")
                     "-e"
                     convert-command)
      (run-with-idle-timer markdown-preview-eww-waiting-idling-second nil
                           #'(lambda ()
                               (markdown-preview-eww--do-convert
                                output-file preview-buf))))))

(provide 'markdown-preview-eww)
;;; markdown-preview-eww.el ends here
