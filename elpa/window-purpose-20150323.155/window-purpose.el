;;; window-purpose.el --- Purpose-based window management for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2015 Bar Magal

;; Author: Bar Magal (2015)
;; Package: purpose
;; Version: 1.2.50
;; Keywords: frames
;; Homepage: https://github.com/bmag/emacs-purpose
;; Package-Requires: ((emacs "24") (cl-lib "0.5") (let-alist "1.0.3") (imenu-list "0.1"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; ---------------------------------------------------------------------
;; Full information can be found on GitHub:
;; https://github.com/bmag/emacs-purpose/wiki
;; ---------------------------------------------------------------------

;; Purpose is a package that introduces the concept of a "purpose" for
;; windows and buffers, and then helps you maintain a robust window
;; layout easily.

;; Installation and Setup:
;; Install Purpose from MELPA, or download it manually from GitHub. If
;; you download manually, add these lines to your init file:
;;    (add-to-list 'load-path "/path/to/purpose")
;;    (require 'window-purpose)
;; To activate Purpose at start-up, add this line to your init file:
;;    (purpose-mode)

;; Purpose Configuration:
;; Customize `purpose-user-mode-purposes', `purpose-user-name-purposes',
;; `purpose-user-regexp-purposes' and
;; `purpose-use-default-configuration'.

;; Basic Usage:
;; 1. Load/Save window/frame layout (see `purpose-load-window-layout',
;;    `purpose-save-window-layout', etc.)
;; 2. Use regular switch-buffer functions - they will not mess your
;;    window layout (Purpose overrides them).
;; 3. If you don't want a window's purpose/buffer to change, dedicate
;;    the window:
;;    C-c , d: `purpose-toggle-window-purpose-dedicated'
;;    C-c , D: `purpose-toggle-window-buffer-dedicated'
;; 4. To use a switch-buffer function that ignores Purpose, prefix it
;;    with C-u. For example, [C-u C-x b] calls
;;    `switch-buffer-without-purpose'.

;;; Code:

(require 'window-purpose-utils)
(require 'window-purpose-configuration)
(require 'window-purpose-core)
(require 'window-purpose-layout)
(require 'window-purpose-switch)
(require 'window-purpose-prefix-overload)
(require 'window-purpose-fixes)

(defconst purpose-version "1.2.50"
  "Purpose's version.")



;;; Commands that work with both `ido' and `helm'
;; `helm' doesn't work well with `ido-find-file' (and other `ido' commands),
;; but `find-file' can't benefit from all of `ido''s features, so we create
;; commands that know when to use `ido-find-file' and when to use `find-file'.
;; the result: Purpose works well both with `ido' and `helm'!!!

(defmacro purpose-ido-caller (ido-fn other-fn)
  "Create an interactive lambda to conditionally call an ido command.
The lambda calls IDO-FN interactively when `ido-mode' is on, otherwise
it calls OTHER-FN interactively.
Example:
  (purpose-ido-caller #'ido-find-file #'find-file)"
  `(lambda (&rest args)
     (interactive)
     (call-interactively (if ido-mode ,ido-fn ,other-fn))))

(defalias 'purpose-friendly-find-file
  (purpose-ido-caller #'ido-find-file #'find-file)
  "Call `find-file' or `ido-find-file' intelligently.
If `ido-mode' is on, call `ido-find-file'.  Otherwise, call `find-file'.
This allows Purpose to work well with both `ido' and `helm'.")

(defalias 'purpose-friendly-find-file-other-window
  (purpose-ido-caller #'ido-find-file-other-window #'find-file-other-window)
  "Call `find-file-other-window' or `ido-find-file-other-window'
intelligently.
If `ido-mode' is on, call `ido-find-file-other-window'.  Otherwise, call
`find-file-other-window'.
This allows Purpose to work well with both `ido' and `helm'.")

(defalias 'purpose-friendly-find-file-other-frame
  (purpose-ido-caller #'ido-find-file-other-frame #'find-file-other-frame)
  "Call `find-file-other-frame' or `ido-find-file-other-frame'
intelligently.
If `ido-mode' is on, call `ido-find-file-other-frame'.  Otherwise, call
`find-file-other-frame'.
This allows Purpose to work well with both `ido' and `helm'.")

(defalias 'purpose-friendly-switch-buffer
  (purpose-ido-caller #'ido-switch-buffer #'switch-to-buffer)
  "Call `switch-to-buffer' or `ido-switch-buffer' intelligently.
If `ido-mode' is on, call `ido-switch-buffer'.  Otherwise, call
`switch-to-buffer'.
This allows Purpose to work well with both `ido' and `helm'.")

(defalias 'purpose-friendly-switch-buffer-other-window
  (purpose-ido-caller #'ido-switch-buffer-other-window
		      #'switch-to-buffer-other-window)
  "Call `switch-to-buffer-other-window' or
`ido-switch-buffer-other-window' intelligently.
If `ido-mode' is on, call `ido-switch-buffer-other-window'.  Otherwise,
call `switch-to-buffer-other-window'.
This allows Purpose to work well with both `ido' and `helm'.")

(defalias 'purpose-friendly-switch-buffer-other-frame
  (purpose-ido-caller #'ido-switch-buffer-other-frame
		      #'switch-to-buffer-other-frame)
  "Call `switch-to-buffer-other-frame' or
`ido-switch-buffer-other-frame' intelligently.
If `ido-mode' is on, call `ido-switch-buffer-other-frame'.  Otherwise,
call `switch-to-buffer-other-frame'.
This allows Purpose to work well with both `ido' and `helm'.")



;;; Commands for using Purpose-less behavior
(defalias 'find-file-without-purpose
  (without-purpose-command #'find-file))

(defalias 'find-file-other-window-without-purpose
  (without-purpose-command #'find-file-other-window))

(defalias 'find-file-other-frame-without-purpose
  (without-purpose-command #'find-file-other-frame))

(defalias 'switch-buffer-without-purpose
  (without-purpose-command #'switch-to-buffer))

(defalias 'switch-buffer-other-window-without-purpose
  (without-purpose-command #'switch-to-buffer-other-window))

(defalias 'switch-buffer-other-frame-without-purpose
  (without-purpose-command #'switch-to-buffer-other-frame))


;;; Overloaded commands: (C-u to get original Purpose-less behavior)
(define-purpose-prefix-overload purpose-find-file-overload
  '(purpose-friendly-find-file find-file-without-purpose))

(define-purpose-prefix-overload purpose-find-file-other-window-overload
  '(purpose-friendly-find-file-other-window find-file-other-window-without-purpose))

(define-purpose-prefix-overload purpose-find-file-other-frame-overload
  '(purpose-friendly-find-file-other-frame find-file-other-frame-without-purpose))

(define-purpose-prefix-overload purpose-switch-buffer-overload
  '(purpose-friendly-switch-buffer
    switch-buffer-without-purpose
    purpose-switch-buffer-with-purpose))

(define-purpose-prefix-overload purpose-switch-buffer-other-window-overload
  '(purpose-friendly-switch-buffer-other-window
    switch-buffer-other-window-without-purpose
    purpose-switch-buffer-with-purpose-other-window))

(define-purpose-prefix-overload purpose-switch-buffer-other-frame-overload
  '(purpose-friendly-switch-buffer-other-frame
    switch-buffer-other-frame-without-purpose
    purpose-switch-buffer-with-purpose-other-frame))



(define-purpose-prefix-overload purpose-delete-window-at
  '(purpose-delete-window-at-bottom
    purpose-delete-window-at-right
    purpose-delete-window-at-top
    purpose-delete-window-at-left))

(defvar purpose-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-x C-f") #'purpose-find-file-overload)
    (define-key map (kbd "C-x 4 f") #'purpose-find-file-other-window-overload)
    (define-key map (kbd "C-x 4 C-f") #'purpose-find-file-other-window-overload)
    (define-key map (kbd "C-x 5 f") #'purpose-find-file-other-frame-overload)
    (define-key map (kbd "C-x 5 C-f") #'purpose-find-file-other-frame-overload)
    
    (define-key map (kbd "C-x b") #'purpose-switch-buffer-overload)
    (define-key map (kbd "C-x 4 b") #'purpose-switch-buffer-other-window-overload)
    (define-key map (kbd "C-x 5 b") #'purpose-switch-buffer-other-frame-overload)

    ;; Helpful for quitting temporary windows. Close in meaning to
    ;; `kill-buffer', so we map it to a close key ("C-x j" is close to
    ;; "C-x k")
    (define-key map (kbd "C-x j") #'quit-window)

    ;; We use "C-c ," for compatibility with key-binding conventions
    (define-key map (kbd "C-c ,") 'purpose-mode-prefix-map)
    (define-prefix-command 'purpose-mode-prefix-map)
    (dolist (binding
	     '(;; switch to any buffer
	       ("o" . purpose-switch-buffer)
	       ("[" . purpose-switch-buffer-other-frame)
	       ("p" . purpose-switch-buffer-other-window)
	       ;; switch to buffer with current buffer's purpose
	       ("b" . purpose-switch-buffer-with-purpose)
	       ("4 b" . purpose-switch-buffer-with-purpose-other-window)
	       ("5 b" . purpose-switch-buffer-with-purpose-other-frame)
	       ;; toggle window dedication (buffer, purpose)
	       ("d" . purpose-toggle-window-purpose-dedicated)
	       ("D" . purpose-toggle-window-buffer-dedicated)
	       ;; delete windows
	       ("w" . purpose-delete-window-at)
	       ("1" . purpose-delete-non-dedicated-windows)))
      (define-key purpose-mode-prefix-map (kbd (car binding)) (cdr binding)))
    
    map)
  "Keymap for Purpose mode.")

;; https://www.gnu.org/software/emacs/manual/html_node/elisp/Menu-Keymaps.html#Menu-Keymaps
;; (defvar purpose-menu-bar-map (make-sparse-keymap "Purpose"))

(defun purpose--modeline-string ()
  "Return the presentation of a window's purpose for display in the
modeline.  The string returned has two forms.  For example, if window's
purpose is 'edit: If (purpose-window-purpose-dedicated-p), return
\"[edit!]\", otherwise return \"[edit]\"."
  (format " [%s%s]"
	  (purpose-window-purpose)
	  (if (purpose-window-purpose-dedicated-p) "!" "")))

(defun purpose--add-advices ()
  "Add all advices needed for Purpose to work.
This function is called when `purpose-mode' is activated."
  (purpose-advice-add 'switch-to-buffer :around
		      #'purpose-switch-to-buffer-advice)
  (purpose-advice-add 'switch-to-buffer-other-window :around
		      #'purpose-switch-to-buffer-other-window-advice)
  (purpose-advice-add 'switch-to-buffer-other-frame :around
		      #'purpose-switch-to-buffer-other-frame-advice)
  (purpose-advice-add 'pop-to-buffer :around
		      #'purpose-pop-to-buffer-advice)
  (purpose-advice-add 'pop-to-buffer-same-window :around
		      #'purpose-pop-to-buffer-same-window-advice)
  (purpose-advice-add 'display-buffer :around
		      #'purpose-display-buffer-advice))

(defun purpose--remove-advices ()
  "Remove all advices needed for Purpose to work.
This function is called when `purpose-mode' is deactivated."
  (purpose-advice-remove 'switch-to-buffer :around
			 #'purpose-switch-to-buffer-advice)
  (purpose-advice-remove 'switch-to-buffer-other-window :around
			 #'purpose-switch-to-buffer-other-window-advice)
  (purpose-advice-remove 'switch-to-buffer-other-frame :around
			 #'purpose-switch-to-buffer-other-frame-advice)
  (purpose-advice-remove 'pop-to-buffer :around
			 #'purpose-pop-to-buffer-advice)
  (purpose-advice-remove 'pop-to-buffer-same-window :around
			 #'purpose-pop-to-buffer-same-window-advice)
  (purpose-advice-remove 'display-buffer :around
			 #'purpose-display-buffer-advice))

;;;###autoload
(define-minor-mode purpose-mode
  nil :global t :lighter (:eval (purpose--modeline-string))
  (if purpose-mode
      (progn
	(purpose--add-advices)
	(setq display-buffer-overriding-action
	      '(purpose--action-function . nil))
	(setq purpose--active-p t)
	(purpose-fix-install))
    (purpose--remove-advices)
    (setq purpose--active-p nil)))

(provide 'window-purpose)
;;; window-purpose.el ends here
