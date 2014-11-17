;;; alchemist-help.el --- Interface to Elixir's documentation

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

;; Mode for searching through Elixir's documentation

;;; Code:

(defgroup alchemist-help nil
  "Interface to Elixir's documentation"
  :prefix "alchemist-help-"
  :group 'alchemist)

(defvar alchemist-help-mix-run-command
  "mix run"
  "The shell command for `mix run`.")

(defface alchemist-help--key-face
  '((t (:inherit font-lock-variable-name-face :bold t :foreground "red")))
  "Fontface for the letter keys in the summary."
  :group 'alchemist-help)

(defvar alchemist-help-search-history '()
  "Stores the search history.")

(defvar alchemist-help-search-history-index 0
  "Stores the current position in the search history.")

(defvar alchemist-help-current-search-text '()
  "Stores the current search text.")

(defun alchemist-help-search-at-point ()
  "Search through `alchemist-help' with the expression under the cursor."
  (interactive)
  (let (p1 p2)
    (save-excursion
      (skip-chars-backward "-a-z0-9A-z./?!")
      (setq p1 (point))
      (skip-chars-forward "-a-z0-9A-z./?!")
      (setq p2 (point))
      (alchemist-help--execute (buffer-substring-no-properties p1 p2)))))

(defun alchemist-help--prepare-completing (string)
  (let* ((completing-collection (alchemist-help--function-string-to-list
                                 (alchemist-help--autocomplete-expand string)))
         (search-term (when (> (length completing-collection) 0)
                        (car completing-collection)))
         (completing-collection (cdr completing-collection))
         (search-term (if (and (> (length completing-collection) 1)
                               (string-match-p ".\\.." search-term))
                          (concat (car (split-string search-term "\\.")) ".")
                        search-term))
         (completing-collection (if (and (equal 1 (length completing-collection))
                                         (string-match-p ".\\.." search-term))
                                    '()
                                  completing-collection))
         (completing-collection (if (string-match-p "\\.$" search-term)
                                    (mapcar (lambda (fn) (concat search-term fn)) completing-collection)
                                  completing-collection))
         (search-term (if (equal (length completing-collection) 1)
                          (car completing-collection)
                        search-term))
         )

    (cond  ((equal (length completing-collection) 1)
            (car completing-collection))
           (completing-collection
            (alchemist-help-completing-read
             "Elixir help: "
             completing-collection
             nil
             nil
             string))
           (t search-term))))

(defun alchemist-help-completing-read (prompt collection predicate require-match initial)
  (completing-read
   prompt
   collection
   predicate require-match initial))

(defun alchemist-help--autocomplete-expand (string)
  (let* ((elixir-code (format "
defmodule Alchemist do
  def expand(exp) do
    {status, result, list } = IEx.Autocomplete.expand(Enum.reverse(exp))

    case { status, result, list } do
      { :yes, [], _ } -> List.insert_at(list, 0, exp)
      { :yes, _,  _ } -> expand(exp ++ result)
                  _t  -> exp
    end
  end
end

IO.inspect Alchemist.expand('%s')
" string))
         (command (if (alchemist-project-p)
                      (format "%s --no-compile -e \"%s\"" alchemist-help-mix-run-command elixir-code)
                    (format "%s -e \"%s\"" alchemist-execute-command elixir-code)))
         )

    (when (alchemist-project-p)
      (alchemist-project--establish-root-directory))

    (shell-command-to-string command)))

(defun alchemist-help--function-string-to-list (string)
  (let* ((search-text (replace-regexp-in-string "\"" "" string))
         (search-text (replace-regexp-in-string "\\[" "" search-text))
         (search-text (replace-regexp-in-string "\\]" "" search-text))
         (search-text (replace-regexp-in-string "'" "" search-text))
         (search-text (replace-regexp-in-string "\n" "" search-text))
         (search-text (replace-regexp-in-string " " "" search-text))
         ) (split-string search-text ",")))

(defun alchemist-help-search-marked-region (begin end)
  "Run `alchemist-help' with the marked region.
Argument BEGIN where the mark starts.
Argument END where the mark ends."
  (interactive "r")
  (let ((region (filter-buffer-substring begin end)))
    (alchemist-help--execute region)))

(defcustom alchemist-help-buffer-name "*elixir help*"
  "Name of the elixir help buffer."
  :type 'string
  :group 'alchemist-help)

(defun alchemist-help--build-code-for-search (string)
  (format "import IEx.Helpers

Application.put_env(:iex, :colors, [enabled: true])

h(%s)" string))

(defun alchemist-help--eval-string (string)
  (alchemist-help--execute-alchemist-with-code-eval-string
   (alchemist-help--build-code-for-search string)))

(defun alchemist-help--eval-string-command (string)
  (let ((command (if (alchemist-project-p)
                     (format "%s --no-compile -e \"%s\"" alchemist-help-mix-run-command string)
                   (format "%s -e \"%s\"" alchemist-execute-command string))))
    command))

(defun alchemist-help--execute-alchemist-with-code-eval-string (string)
  (let ((content (shell-command-to-string (alchemist-help--eval-string-command string))))
    (alchemist-help--initialize-buffer content default-directory)))

(defun alchemist-help-bad-search-output-p (string)
  (let ((match (or (string-match-p "No documentation for " string)
                   (string-match-p "Invalid arguments for h helper" string)
                   (string-match-p "** (TokenMissingError)" string)
                   (string-match-p "** (SyntaxError)" string)
                   (string-match-p "** (FunctionClauseError)" string)
                   (string-match-p "** (CompileError)" string)
                   (string-match-p "Could not load module" string))))
    (if match
        t
      nil)))

(defun alchemist-help--initialize-buffer (content d-directory)
  (pop-to-buffer alchemist-help-buffer-name)
  (setq default-directory d-directory)
  (setq buffer-undo-list nil)
  (let ((inhibit-read-only t)
        (buffer-undo-list t)
        (position-current-search-text (cl-position alchemist-help-current-search-text
                                                   alchemist-help-search-history)))
    (cond ((alchemist-help-bad-search-output-p content)
           (message (propertize
                     (format "No documentation for [ %s ] found." alchemist-help-current-search-text)
                     'face 'alchemist-help--key-face)))
          (t
           (erase-buffer)
           (insert content)
           (when (and alchemist-help-search-history
                      position-current-search-text)
             (setq alchemist-help-search-history-index position-current-search-text))
           (unless (memq 'alchemist-help-current-search-text alchemist-help-search-history)
             (add-to-list 'alchemist-help-search-history alchemist-help-current-search-text))))
    (delete-matching-lines "do not show this result in output" (point-min) (point-max))
    (delete-matching-lines "^Compiled lib\\/" (point-min) (point-max))

    (ansi-color-apply-on-region (point-min) (point-max))
    (toggle-read-only 1)
    (alchemist-help-minor-mode 1)))

(defun alchemist-help-minor-mode-key-binding-summary ()
  (interactive)
  (message
   (concat "[" (propertize "q" 'face 'alchemist-help--key-face)
           "]-quit ["
           (propertize "e" 'face 'alchemist-help--key-face)
           "]-search-at-point ["
           (propertize "m" 'face 'alchemist-help--key-face)
           "]-search-marked-region ["
           (propertize "n" 'face 'alchemist-help--key-face)
           "]-next-search ["
           (propertize "p" 'face 'alchemist-help--key-face)
           "]-previous-search ["
           (propertize "s" 'face 'alchemist-help--key-face)
           "]-search ["
           (propertize "?" 'face 'alchemist-help--key-face)
           "]-keys")))

(defun alchemist-help-next-search ()
  "Switches to the next search in the history."
  (interactive)
  (let ((current-position (cl-position alchemist-help-current-search-text alchemist-help-search-history))
        (next-position (- alchemist-help-search-history-index 1)))
    (unless (< next-position 0)
      (setq alchemist-help-search-history-index next-position)
      (alchemist-help (nth next-position alchemist-help-search-history)))))

(defun alchemist-help-previous-search ()
  "Switches to the previous search in the history."
  (interactive)
  (let ((current-position (cl-position alchemist-help-current-search-text alchemist-help-search-history))
        (next-position (+ alchemist-help-search-history-index 1)))
    (unless (> next-position (- (length alchemist-help-search-history) 1))
      (setq alchemist-help-search-history-index next-position)
      (alchemist-help (nth next-position alchemist-help-search-history)))))

(define-minor-mode alchemist-help-minor-mode
  "Minor mode for displaying elixir help."
  :group 'alchemist-help
  :keymap '(("q" . quit-window)
            ("e" . alchemist-help-search-at-point)
            ("m" . alchemist-help-search-marked-region)
            ("s" . alchemist-help)
            ("n" . alchemist-help-next-search)
            ("p" . alchemist-help-previous-search)
            ("?" . alchemist-help-minor-mode-key-binding-summary)))

(defun alchemist-help (search)
  (interactive "MElixir help: ")
  (alchemist-help--execute search))

(defun alchemist-help-history (search)
  (interactive
   (list
    (completing-read "Elixir help history: " alchemist-help-search-history nil nil "")))
  (alchemist-help--execute search))

(defun alchemist-help--execute (search)
  (let ((old-directory default-directory)
        (search (if (string-match-p ".\\..+\/[0-9]" search)
                    search
                  (alchemist-help--prepare-completing search))))
    (setq alchemist-help-current-search-text search)
    (when (alchemist-project-p)
      (alchemist-project--establish-root-directory))
    (alchemist-help--eval-string (alchemist-utils--clear-search-text search))
    (when (alchemist-project-p)
      (cd old-directory))))

;; These functions will not be available in the release of version 1.0.0
(define-obsolete-function-alias 'alchemist-help-sexp-at-point 'alchemist-help-search-at-point)
(define-obsolete-function-alias 'alchemist-help-module-sexp-at-point 'alchemist-help-search-at-point)

(provide 'alchemist-help)

;;; alchemist-help.el ends here
