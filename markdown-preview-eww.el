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
(require 'markdown-mode)

(defvar markdown-preview-eww-process-name "convert-from-md-to-html"
  "Process name of a converter.")

(defvar-local markdown-preview-eww--output-file nil
  "The absolute path to the temporary output file for this buffer.")

(defvar markdown-preview-eww-waiting-idling-second 1
  "Seconds of convert waiting")

(defvar *markdown-preview-eww-output-file* nil
  "The absolute path to the temporary output file for markdown preview.")

(defvar *markdown-preview-eww-preview-buffer* nil
  "The markdown preview buffer.")

(defvar *markdown-preview-eww-timer* nil
  "The timer object for markdown preview.")

(defvar markdown-preview-eww-rbin "ruby"
  "The Ruby binary path.")

(defun markdown-preview-eww-convert-command (output-file-name)
  "Return a Ruby command string to convert markdown OUTPUT-FILE-NAME."
  (format "$stderr.reopen($stdout)
require \"redcarpet\"

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
while doc = gets(\"\\0\")
  doc.chomp!(\"\\0\")
  File.write(\"%s\", markdown.render(doc))
end" output-file-name))

(defun markdown-preview-eww-side-window-p (&optional window)
  "Return non-nil if WINDOW is a side window.
A side window is identified by the `window-side' window parameter.
WINDOW defaults to the selected window."
  (let ((win (or window (selected-window))))
    (assq 'window-side (window-parameters win))))

(defun markdown-preview-eww-at-right-of (current-buffer other-buffer)
  "Set OTHER-BUFFER at right of CURRENT-BUFFER."
  (if (and (get-buffer current-buffer) (get-buffer other-buffer))
    (with-current-buffer current-buffer
      (switch-to-buffer current-buffer)
      (if (> (length (mapcar #'window-buffer (window-list))) 1)
        (if (markdown-preview-eww-side-window-p)
          (delete-window)
          (delete-other-windows)))
      (display-buffer other-buffer
        '(display-buffer-in-side-window .
           ((side . right)
             (window-width . 0.5)))))))

(defun markdown-preview-eww--do-convert (ofile markdown-preview-mdbuf)
  "Convert markdown in MARKDOWN-PREVIEW-MDBUF to HTML and save it to OFILE."
  (let* ((doc (with-current-buffer markdown-preview-mdbuf
                (buffer-substring-no-properties (point-min) (point-max)))))
    (or (get-process markdown-preview-eww-process-name)
      (error "No conversion process"))
    (if (and ofile (get-process markdown-preview-eww-process-name))
      (progn
        (process-send-string
          (get-process markdown-preview-eww-process-name)
          (concat doc "\0"))
        (cond ((get-buffer "*eww*")
                (when (equal markdown-preview-mdbuf (current-buffer))
                  (other-window 1))
                (switch-to-buffer "*eww*")
                (eww-open-file ofile)
                (markdown-preview-eww-at-right-of markdown-preview-mdbuf "*eww*")
                )
          (t
            (message "no *eww* buffer, creating new one...")
            (if (> (length (mapcar #'window-buffer (window-list))) 1)
              (delete-other-windows))
            (split-window-right)
            (other-window 1)
            (eww-open-file ofile)))))))

(defun markdown-preview-eww-process-sentinel (process event)
  "Sentinel for markdown preview PROCESS with EVENT."
  (when (memq (process-status process) '(exit signal))
    (message "Markdown preview process %s ended with event: %s"
      (process-name process) event)
    (when *markdown-preview-eww-timer*
      (cancel-timer *markdown-preview-eww-timer*)
      (setq *markdown-preview-eww-timer* nil))
    (setq *markdown-preview-eww-output-file* nil)
    (setq *markdown-preview-eww-preview-buffer* nil)
    (and *markdown-preview-eww-output-file*
      (delete-file *markdown-preview-eww-output-file*))
    (and (get-buffer "*eww*") (kill-buffer "*eww*"))))

;;;### autoload
(defun markdown-preview-eww ()
  "Start a realtime markdown preview."
  (interactive)
  (and (executable-find markdown-preview-eww-rbin)
    (equal major-mode 'markdown-mode)
    (not (get-process markdown-preview-eww-process-name))
    (let* ((process-connection-type nil)
            (output-file (make-temp-file "markdown-preview-" nil ".html"))
            (convert-command (markdown-preview-eww-convert-command output-file))
            (preview-buf (current-buffer)))
      (start-process markdown-preview-eww-process-name
        nil
        (executable-find markdown-preview-eww-rbin)
        "-e"
        convert-command)

      (set-process-sentinel
        (get-process markdown-preview-eww-process-name)
        #'markdown-preview-eww-process-sentinel)

      (with-current-buffer preview-buf
        (switch-to-buffer preview-buf)
        (split-window-right)
        (other-window 1))

      (setq *markdown-preview-eww-output-file* output-file)
      (setq *markdown-preview-eww-preview-buffer* preview-buf)
      (setq *markdown-preview-eww-timer*
        (run-with-idle-timer
          markdown-preview-eww-waiting-idling-second
          t
          #'(lambda ()
              (markdown-preview-eww--do-convert
                *markdown-preview-eww-output-file*
                *markdown-preview-eww-preview-buffer*)))))))
(bind-key (kbd "C-c z") 'markdown-preview-eww markdown-mode-map)

;;;### autoload
(defun markdown-preview-eww-kill ()
  "Kill the markdown preview process and timer."
  (interactive)
  (let ((process (get-process markdown-preview-eww-process-name)))
    (and process (kill-process process))
    (and *markdown-preview-eww-timer*
      (cancel-timer *markdown-preview-eww-timer*))))
(bind-key (kbd "C-c k") 'markdown-preview-eww-kill markdown-mode-map)


(provide 'markdown-preview-eww)
;;; markdown-preview-eww.el ends here
