;;; alchemist-project.el --- API to identify Elixir mix projects.

;; Copyright © 2014 Samuel Tonini

;; Author: Samuel Tonini <tonini.samuel@gmail.com

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
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; API to identify Elixir mix projects.

;;; Code:

(require 'cl)
(require 'json)

(defgroup alchemist-project nil
  "API to identify Elixir mix projects."
  :prefix "alchemist-help-"
  :group 'alchemist)

(defcustom alchemist-project-config-filename ".alchemist"
  "Name of the file which holds the Elixir project setup."
  :type 'string
  :group 'alchemist)

(defcustom alchemist-project-codebase-complete-and-docs-enabled t
  "When `t', it enables the completion and documention lookup for
the project specific codebase."
  :type 'string
  :group 'alchemist)

(defun alchemist-project-toggle-complete-and-docs ()
  "Toggle between the complete and documention lookup for current elixir codebase."
  (interactive)
  (if alchemist-project-codebase-complete-and-docs-enabled
      (setq alchemist-project-codebase-complete-and-docs-enabled nil)
    (setq alchemist-project-codebase-complete-and-docs-enabled t))
  (if alchemist-project-codebase-complete-and-docs-enabled
      (message "completion and documention for project codebase is enabled")
    (message "The completion and documention for project codebase is disabled")))

(defun alchemist-project--load-complete-and-docs-enabled-setting ()
  (let ((config (gethash "codebase-complete-and-docs-enabled" (alchemist-project-config))))
    (if config
        (intern config)
      alchemist-project-codebase-complete-and-docs-enabled)))

(defun alchemist-project--config-filepath ()
  "Return the path to the config file."
  (format "%s/%s"
          (alchemist-project-root)
          alchemist-project-config-filename))

(defun alchemist-project--config-exists-p ()
  "Check if project config file exists."
  (file-exists-p (alchemist-project--config-filepath)))

(defun alchemist-project-config ()
  "Return the current Elixir project configs."
  (let* ((json-object-type 'hash-table)
         (config (if (alchemist-project--config-exists-p)
                     (json-read-from-string
                      (with-temp-buffer
                        (insert-file-contents (alchemist-project--config-filepath))
                        (buffer-string)))
                   (make-hash-table :test 'equal))))
    config))

(defvar alchemist-project-root-indicators
  '("mix.exs")
  "list of file-/directory-names which indicate a root of a elixir project")

(defvar alchemist-project-deps-indicators
  '(".hex")
  "list of file-/directory-names which indicate a root of a elixir project")

(defun alchemist-project-p ()
  "Returns whether alchemist has access to a elixir project root or not"
  (stringp (alchemist-project-root)))

(defun alchemist-project-parent-directory (a-directory)
  "Returns the directory of which a-directory is a child"
  (file-name-directory (directory-file-name a-directory)))

(defun alchemist-project-root-directory-p (a-directory)
  "Returns t if a-directory is the root"
  (equal a-directory (alchemist-project-parent-directory a-directory)))

(defun alchemist-project-root (&optional directory)
  "Finds the root directory of the project by walking the directory tree until it finds a project root indicator."
  (let* ((directory (file-name-as-directory (or directory (expand-file-name default-directory))))
         (present-files (directory-files directory)))
    (cond ((alchemist-project-root-directory-p directory) nil)
          ((> (length (intersection present-files alchemist-project-deps-indicators :test 'string=)) 0)
           (alchemist-project-root (file-name-directory (directory-file-name directory))))
          ((> (length (intersection present-files alchemist-project-root-indicators :test 'string=)) 0) directory)
          (t (alchemist-project-root (file-name-directory (directory-file-name directory)))))))

(defun alchemist-project--establish-root-directory ()
  "Set the default-directory to the Elixir project root."
  (let ((project-root (alchemist-project-root)))
    (when project-root
      (setq default-directory project-root))))

(defun alchemist-project-name ()
  "Return the name of the current Elixir project."
  (if (alchemist-project-p)
      (car (cdr (reverse (split-string (alchemist-project-root) "/"))))
    ""))

(provide 'alchemist-project)

;;; alchemist-project.el ends here
