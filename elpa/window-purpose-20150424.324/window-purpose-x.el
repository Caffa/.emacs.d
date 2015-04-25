;;; window-purpose-x.el --- Extensions for Purpose -*- lexical-binding: t -*-

;; Copyright (C) 2015 Bar Magal

;; Author: Bar Magal (2015)
;; Package: purpose

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
;; File containing extensions for Purpose.
;; Extensions included:
;; - code1: 4-window display: main edit window, `dired' side window,
;;   `ibuffer' side window and `imenu-list' side window.
;; - magit: purpose configurations for magit.
;; - golden-ratio: make `golden-ratio-mode' work correctly with Purpose.
;; - popup-switcher: command `purpose-x-psw-switch-buffer-with-purpose'
;;   uses `popup-switcher' to switch to another buffer with the same
;;   purpose as the current buffer

;;; Code:

(require 'window-purpose)

;;; --- purpose-x-code1 ---
;;; purpose-x-code1 extension creates a 4-window display:
;;; 1 main window for code buffers (purpose 'edit)
;;; 3 sub windows:
;;; - dired window: show directory of current buffer
;;; - ibuffer window: show currently open files
;;; - imenu-list window: show imenu of current buffer

(require 'dired)
(require 'ibuffer)
(require 'ibuf-ext)
(require 'imenu-list)

(defvar purpose-x-code1--window-layout
  '(nil
    (0 0 152 35)
    (t
     (0 0 29 35)
     (:purpose dired :purpose-dedicated t :width 0.16 :height 0.5 :edges
	       (0.0 0.0 0.19333333333333333 0.5))
     (:purpose buffers :purpose-dedicated t :width 0.16 :height 0.4722222222222222 :edges
	       (0.0 0.5 0.19333333333333333 0.9722222222222222)))
    (:purpose edit :purpose-dedicated t :width 0.6 :height 0.9722222222222222 :edges
	      (0.19333333333333333 0.0 0.8266666666666667 0.9722222222222222))
    (:purpose ilist :purpose-dedicated t :width 0.15333333333333332 :height 0.9722222222222222 :edges
	      (0.8266666666666667 0.0 1.0133333333333334 0.9722222222222222)))
  "Window layout for purpose-x-code1-dired-ibuffer.
Has a main 'edit window, and two side windows - 'dired and 'buffers.
All windows are purpose-dedicated.")

;; the name arg ("purpose-x-code1") is necessary for Emacs 24.3 and older
(defvar purpose-x-code1-purpose-config (purpose-conf "purpose-x-code1"
					    :mode-purposes
					    '((ibuffer-mode . buffers)
					      (dired-mode . dired)
					      (imenu-list-major-mode . ilist))))

(define-ibuffer-filter purpose-x-code1-ibuffer-files-only
    "Display only buffers that are bound to files."
  ()
  (buffer-file-name buf))

(defun purpose-x-code1--setup-ibuffer ()
  "Set up ibuffer settings."
  (add-hook 'ibuffer-mode-hook
  	    #'(lambda ()
  		(ibuffer-filter-by-purpose-x-code1-ibuffer-files-only nil)))
  (add-hook 'ibuffer-mode-hook #'ibuffer-auto-mode)
  (setq ibuffer-formats '((mark " " name)))
  (setq ibuffer-display-summary nil)
  (setq ibuffer-use-header-line nil)
  ;; not sure if we want this...
  ;; (setq ibuffer-default-shrink-to-minimum-size t)
  (when (get-buffer "*Ibuffer*")
    (kill-buffer "*Ibuffer*"))
  (ibuffer-list-buffers))

(defun purpose-x-code1--unset-ibuffer ()
  "Unset ibuffer settings."
  (remove-hook 'ibuffer-mode-hook
	       #'(lambda ()
		   (ibuffer-filter-by-purpose-x-code1-ibuffer-files-only nil)))
  (remove-hook 'ibuffer-mode-hook #'ibuffer-auto-mode)
  (setq ibuffer-formats '((mark modified read-only " "
				(name 18 18 :left :elide)
				" "
				(size 9 -1 :right)
				" "
				(mode 16 16 :left :elide)
				" " filename-and-process)
			  (mark " "
				(name 16 -1)
				" " filename)))
  (setq ibuffer-display-summary t)
  (setq ibuffer-use-header-line t))

(defun purpose-x-code1-update-dired ()
  "Update free dired window with current buffer's directory.
If a non-buffer-dedicated window with purpose 'dired exists, display
the directory of the current buffer in that window, using `dired'.
If there is no window available, do nothing.
If current buffer doesn't have a filename, do nothing."
  (when (and (buffer-file-name)
	     (cl-delete-if #'window-dedicated-p (purpose-windows-with-purpose 'dired)))
    (save-selected-window
      (dired (file-name-directory (buffer-file-name)))
      (when (fboundp 'dired-hide-details-mode)
	(dired-hide-details-mode)))))

(defun purpose-x-code1--setup-dired ()
  "Setup dired settings."
  (add-hook 'purpose-select-buffer-hook #'purpose-x-code1-update-dired))

(defun purpose-x-code1--unset-dired ()
  "Unset dired settings."
  (remove-hook 'purpose-select-buffer-hook #'purpose-x-code1-update-dired))

(defun purpose-x-code1--setup-imenu-list ()
  "Setup imenu-list settings."
  (add-hook 'purpose-select-buffer-hook #'imenu-list-update-safe)
  (imenu-list-minor-mode 1))

(defun purpose-x-code1--unset-imenu-list ()
  "Unset imenu-list settings."
  (remove-hook 'purpose-select-buffer-hook #'imenu-list-update-safe)
  (imenu-list-minor-mode -1))

;;;###autoload
(defun purpose-x-code1-setup ()
  "Setup purpose-x-code1.
This setup includes 4 windows:
1. dedicated 'edit window
2. dedicated 'dired window.  This window shows the current buffer's
directory in a special window, using `dired' and
`dired-hide-details-mode' (if available).
3. dedicated 'buffers window.  This window shows the currently open
files, using `ibuffer'.
4. dedicated 'ilist window.  This window shows the current buffer's
imenu."
  (interactive)
  (purpose-set-extension-configuration :purpose-x-code1 purpose-x-code1-purpose-config)
  (purpose-x-code1--setup-ibuffer)
  (purpose-x-code1--setup-dired)
  (purpose-x-code1--setup-imenu-list)
  (purpose-set-window-layout purpose-x-code1--window-layout))

(defun purpose-x-code1-unset ()
  "Unset purpose-x-code1."
  (interactive)
  (purpose-del-extension-configuration :purpose-x-code1)
  (purpose-x-code1--unset-ibuffer)
  (purpose-x-code1--unset-dired)
  (purpose-x-code1--unset-imenu-list))

;;; --- purpose-x-code1 ends here ---



;;; --- purpose-x-magit ---
;;; purpose-x-magit extension provides purpose configuration for magit.
;;; Two configurations available:
;;; - `purpose-x-magit-single-conf': all magit windows have the same purpose
;;;                                  ('magit)
;;; - `purpose-x-magit-multi-conf': each magit major-mode has a seperate
;;;                                 purpose ('magit-status, 'magit-diff, ...)
;;; Use these commands to enable and disable magit's purpose configurations:
;;; - `purpose-x-magit-single-on'
;;; - `purpose-x-magit-multi-on'
;;; - `purpose-x-magit-off'

(defvar purpose-x-magit-single-conf
  (purpose-conf "magit-single"
		:regexp-purposes '(("^\\*magit" . magit)))
  "Configuration that gives each magit major-mode the same purpose.")

(defvar purpose-x-magit-multi-conf
  (purpose-conf
   "magit-multi"
   :mode-purposes '((magit-diff-mode . magit-diff)
		    (magit-status-mode . magit-status)
		    (magit-log-mode . magit-log)
		    (magit-commit-mode . magit-commit)
		    (magit-cherry-mode . magit-cherry)
		    (magit-branch-manager-mode . magit-branch-manager)
		    (magit-process-mode . magit-process)
		    (magit-reflog-mode . magit-reflog)
		    (magit-wazzup-mode . magit-wazzup)))
  "Configuration that gives each magit major-mode its own purpose.")

;;;###autoload
(defun purpose-x-magit-single-on ()
  "Turn on magit-single purpose configuration."
  (interactive)
  (purpose-set-extension-configuration :magit purpose-x-magit-single-conf))

;;;###autoload
(defun purpose-x-magit-multi-on ()
  "Turn on magit-multi purpose configuration."
  (interactive)
  (purpose-set-extension-configuration :magit purpose-x-magit-multi-conf))

(defun purpose-x-magit-off ()
  "Turn off magit purpose configuration (single or multi)."
  (interactive)
  (purpose-del-extension-configuration :magit))

;;; --- purpose-x-magit ends here ---



;;; --- purpose-x-golden-ration ---
;;; Make `purpose-mode' and `golden-ratio-mode' work together properly.
;;; Basically, this adds a hook to `purpose-select-buffer-hook' so
;;; `golden-ratio' is called when a buffer is selected via Purpose.

(defun purpose-x-sync-golden-ratio ()
  "Add/remove `golden-ratio' to `purpose-select-buffer-hook'.
Add `golden-ratio' at the end of `purpose-select-buffer-hook' if
`golden-ratio-mode' is on, otherwise remove it."
  (if golden-ratio-mode
      (add-hook 'purpose-select-buffer-hook #'golden-ratio t)
    (remove-hook 'purpose-select-buffer-hook #'golden-ratio)))

;;;###autoload
(defun purpose-x-golden-ratio-setup ()
  "Make `golden-ratio-mode' aware of `purpose-mode'."
  (interactive)
  (add-hook 'golden-ratio-mode-hook #'purpose-x-sync-golden-ratio)
  (when (and (boundp 'golden-ratio-mode) golden-ratio-mode)
    (add-hook 'purpose-select-buffer-hook #'golden-ratio t)))

(defun purpose-x-golden-ratio-unset ()
  "Make `golden-ratio-mode' forget about `purpose-mode'."
  (interactive)
  (remove-hook 'golden-ratio-mode-hook #'purpose-x-sync-golden-ratio)
  (when (and (boundp 'golden-ratio-mode) golden-ratio-mode)
    (remove-hook 'purpose-select-buffer-hook #'golden-ratio)))

;;; --- purpose-x-golden-ration ends here ---



;;; --- purpose-x-popup-switcher ---
;;; A command for combinining `popup-switcher' with
;;; `purpose-switch-buffer-with-purpose'.
;;; This requires package `popup-switcher'

(when (require 'popup-switcher nil t)
  (defun purpose-x-psw-switch-buffer-with-purpose ()
    "Use `psw-switcher' to open another buffer with the current purpose."
    (interactive)
    (psw-switcher :items-list (purpose-buffers-with-purpose
			       (purpose-buffer-purpose (current-buffer)))
		  :item-name-getter #'buffer-name
		  :switcher #'purpose-switch-buffer)))

;;; --- purpose-x-popup-switcher ends here ---



;;; --- purpose-x-popwin ---
;;; An extension for displaying buffers in a temporary popup-window, similar
;;; to the `popwin' package.

(defcustom purpose-x-popwin-position 'bottom
  "Position for the popup window.
Legal values for this variable are 'top, 'bottom, 'left and 'right.  It
is also possible to set this variable to a function.  That function will
be used to create new popup windows and should be a display function
compatible with `display-buffer'."
  :group 'purpose
  :type '(choice (const top)
                 (const bottom)
                 (const left)
                 (const right)
                 function)
  :package-version "1.3.50")

(defcustom purpose-x-popwin-width 0.5
  "Width of popup window when displayed at left or right.
Can have the same values as `purpose-display-at-left-width' and
`purpose-display-at-right-width'"
  :group 'purpose
  :type '(choice number
                 (const nil))
  :package-version "1.3.50")

(defcustom purpose-x-popwin-height 0.5
  "Height of popup window when displayed at top or bottom.
Can have the same values as `purpose-display-at-top-height' and
`purpose-display-at-bottom-height'"
  :group 'purpose
  :type '(choice number
                 (const nil))
  :package-version "1.3.50")

(defcustom purpose-x-popwin-major-modes '(help-mode
                                          compilation-mode
                                          occur-mode)
  "List of major modes that should be opened as popup windows.
When changing the value of this variable in elisp code, you should call
`purpose-x-popwin-update-conf' for the change to take effect."
  :group 'purpose
  :type 'list
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-x-popwin-update-conf)))
  :initialize 'custom-initialize-default
  :package-version "1.3.50")

(defcustom purpose-x-popwin-buffer-names '("*Shell Command Output*")
  "List of buffer names that should be opened as popup windows.
Buffers whose name is contained in this list will be opened as popup
windows.
When changing the value of this variable in elisp code, you should call
`purpose-x-popwin-update-conf' for the change to take effect."
  :group 'purpose
  :type 'list
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-x-popwin-update-conf)))
  :initialize 'custom-initialize-default
  :package-version "1.3.50")

(defcustom purpose-x-popwin-buffer-name-regexps nil
  "List of regexp that should be opened as popup windows.
Buffers whose name matches a regexp in this list will be opened as popup
windows.
When changing the value of this variable in elisp code, you should call
`purpose-x-popwin-update-conf' for the change to take effect."
  :group 'purpose
  :type 'list
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-x-popwin-update-conf)))
  :initialize 'custom-initialize-default
  :package-version "1.3.50")

(defun purpose-x-popupify-purpose (purpose &optional display-fn)
  "Set up a popup-like behavior for buffers with purpose PURPOSE.
DISPLAY-FN is the display function to use for creating the popup window
for purpose PURPOSE, and defaults to `purpose-display-at-bottom'."
  (setq purpose-special-action-sequences
        (cl-delete purpose purpose-special-action-sequences :key #'car))
  (push (list purpose
              #'purpose-display-reuse-window-buffer
              #'purpose-display-reuse-window-purpose
              (or display-fn #'purpose-display-at-bottom))
        purpose-special-action-sequences))

(defun purpose-x-unpopupify-purpose (purpose)
  "Remove popup-like behavior for buffers purpose PURPOSE.
This actually removes any special treatment for PURPOSE in
`purpose-special-action-sequences', not only popup-like behavior."
  (setq purpose-special-action-sequences
        (cl-delete purpose purpose-special-action-sequences :key #'car)))

(defun purpose-x-popwin-update-conf ()
  "Update purpose-x-popwin's purpose configuration.
The configuration is updated according to
`purpose-x-popwin-major-modes', `purpose-x-popwin-buffer-names' and
`purpose-x-popwin-buffer-name-regexps'."
  (interactive)
  (cl-flet ((joiner (x) (cons x 'popup)))
    (let ((conf (purpose-conf
                 "popwin"
                 :mode-purposes (mapcar #'joiner purpose-x-popwin-major-modes)
                 :name-purposes (mapcar #'joiner purpose-x-popwin-buffer-names)
                 :regexp-purposes (mapcar #'joiner
                                          purpose-x-popwin-buffer-name-regexps))))
      (purpose-set-extension-configuration :popwin conf))))

(defun purpose-x-popwin-get-display-function ()
  "Return function for creating new popup windows.
The function is determined by the value of `purpose-x-popwin-position'."
  (or (cl-case purpose-x-popwin-position
        ('top 'purpose-display-at-top)
        ('bottom 'purpose-display-at-bottom)
        ('left 'purpose-display-at-left)
        ('right 'purpose-display-at-right))
      (and (functionp purpose-x-popwin-position)
           purpose-x-popwin-position)
      (user-error "purpose-x-popwin-position has an invalid value: %S"
                  purpose-x-popwin-position)))

(defun purpose-x-popwin-display-buffer (buffer alist)
  "Display BUFFER in a popup window."
  (let ((purpose-display-at-top-height purpose-x-popwin-height)
        (purpose-display-at-bottom-height purpose-x-popwin-height)
        (purpose-display-at-left-width purpose-x-popwin-width)
        (purpose-display-at-right-width purpose-x-popwin-width))
    (funcall (purpose-x-popwin-get-display-function) buffer alist)))

(defun purpose-x-popwin-close-windows ()
  "Delete all popup windows.
Internally, this function works be deleting all windows that have the
'popup purpose."
  (interactive)
  (mapc #'delete-window (purpose-windows-with-purpose 'popup)))

(defun purpose-x-popwin-setup ()
  "Activate `popwin' emulation.
This extension treats certain buffers as \"popup\" buffers and displays
them in a special popup window.
Currently, the popup window is not closed automatically.  To close it,
use the command `purpose-x-popwin-close-windows' - you probably want to
bind it to some key.
You can control which buffers are treated as popup buffers by changing
the variables `purpose-x-popwin-major-modes',
`purpose-x-popwin-buffer-names' and
`purpose-x-popwin-buffer-name-regexps'.
Look at `purpose-x-popwin-*' variables and functions to learn more."
  (interactive)
  (purpose-x-popwin-update-conf)
  (setq purpose-special-action-sequences
        (cl-delete 'popup purpose-special-action-sequences :key #'car))
  (purpose-x-popupify-purpose 'popup #'purpose-x-popwin-display-buffer))

(defun purpose-x-popwin-unset ()
  "Deactivate `popwin' emulation."
  (interactive)
  (purpose-del-extension-configuration :popwin)
  (purpose-x-unpopupify-purpose 'popup))

;;; --- purpose-x-popup ends here ---

(provide 'window-purpose-x)
;;; window-purpose-x.el ends here
