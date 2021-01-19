;;; helm-rg.el --- Helm frontend for rg (ripgrep)

;; Copyright (C) 2016 Sangho Na <microamp@protonmail.com>
;;
;; Author: Sangho Na <microamp@protonmail.com>
;; Version: 0.0.1
;; Keywords: rg ripgrep search
;; Homepage: https://github.com/microamp/helm-rg

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation, either version 3 of the License, or (at your option) any later
;; version.

;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
;; details.

;; You should have received a copy of the GNU General Public License along with
;; this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Helm frontend for rg (ripgrep).

;;; Code:

(require 'helm)
(require 's)

(defcustom helm-rg-executable "rg"
  "Default executable for rg (ripgrep)."
  :type 'string
  :group 'helm-rg)

(defcustom helm-rg-requires-pattern 3
  "Minimum pattern length. Default is 3."
  :type 'integer
  :group 'helm-rg)

(defcustom helm-rg-ignore-case nil
  "Case insensitive search."
  :type 'boolean
  :group 'helm-rg)

(defcustom helm-rg-hidden nil
  "Search hidden directories and files. (Hidden directories and files are
skipped by default.)"
  :type 'boolean
  :group 'helm-rg)

(defcustom helm-rg-smart-case nil
  "Search case insensitively if the pattern is all lowercase. Search case
sensitively otherwise."
  :type 'boolean
  :group 'helm-rg)

(defvar helm-rg-process-name "helm-rg")

(defvar helm-rg-path nil)

(defvar helm-rg-source
  (helm-build-async-source "rg (ripgrep)"
    :candidates-process 'helm-rg--candidates-process
    :filter-one-by-one 'helm-rg--filter-one-by-one
    :action 'helm-rg--action
    :candidate-number-limit 9999
    :requires-pattern helm-rg-requires-pattern))

(defun helm-rg-command ()
  (-filter 'identity
           (list helm-rg-executable
                 "--no-heading"
                 (when helm-rg-ignore-case "--ignore-case")
                 (when helm-rg-hidden "--hidden")
                 (when helm-rg-smart-case "--smart-case")
                 "-n"
                 helm-pattern
                 helm-rg-path)))

(defun helm-rg--candidates-process ()
  (let* ((cmd (helm-rg-command))
         (proc (apply 'start-file-process
                      helm-rg-process-name
                      helm-buffer
                      cmd)))
    (prog1 proc
      (set-process-sentinel
       (get-buffer-process helm-buffer)
       #'(lambda (process event)
           (helm-process-deferred-sentinel-hook
            process
            event
            helm-rg-path))))))

(defun helm-rg--filter-one-by-one (candidate)
  (let* ((split (s-split-up-to ":" candidate 2))
         (filename (nth 0 split))
         (filename-short (s-chop-prefix helm-rg-path filename))
         (line-number (nth 1 split))
         (value (nth 2 split))
         (highlighted (helm-grep-highlight-match value t)))
    (cons (concat (propertize filename-short 'face 'helm-grep-file)
                  ":"
                  (propertize line-number 'face 'helm-grep-lineno)
                  ":"
                  (or highlighted value))
          candidate)))

(defun helm-rg--action (candidate)
  (let* ((split (s-split-up-to ":" candidate 2))
         (filename (nth 0 split))
         (line-number (string-to-number (nth 1 split))))
    (progn
      (find-file filename)
      (helm-goto-line line-number)
      (ignore-errors
        (re-search-forward helm-pattern (line-end-position) t)
        (goto-char (match-beginning 0))))))

(defun get-symbol-at-point ()
  "Get the name of the symbol at point, or an empty string if there is no such
symbol."
  (let ((symbol (symbol-at-point)))
    (if symbol (symbol-name symbol) "")))

;;;###autoload
(defun helm-rg (&optional pattern basedir)
  (interactive)
  (unless (executable-find helm-rg-executable)
    (error "rg not installed"))
  (progn
    (setq helm-rg-path (or basedir default-directory))
    (helm
     :buffer "*helm rg*"
     :input (or pattern "")
     :sources '(helm-rg-source))))

;;;###autoload
(defun helm-rg-at-point ()
  (interactive)
  (helm-rg (get-symbol-at-point)))

;;;###autoload
(defun helm-projectile-rg (&optional pattern)
  (interactive)
  (progn
    (require 'projectile)
    (let ((project-root (projectile-project-root)))
      (helm-rg (or pattern "") project-root))))

;;;###autoload
(defun helm-projectile-rg-at-point ()
  (interactive)
  (helm-projectile-rg (get-symbol-at-point)))

(provide 'helm-rg)
