;;; nim-helper.el ---
;;; Commentary:
;; nim-nav-* and nim-info-* functions refer to each other, so they
;; can not split...
;;; Code:

(require 'nim-util)

(defvar nim-nav-beginning-of-defun-regexp
  (nim-rx line-start (* space) defun (+ space) (group symbol-name))
  "Regexp matching class or function definition.
The name of the defun should be grouped so it can be retrieved
via `match-string'.")

(defun nim-font-lock-syntactic-face-function (syntax-ppss)
  "Return syntactic face given SYNTAX-PPSS."
  (if (nth 4 syntax-ppss) ; if nth 4 is exist, it means inside comment.
      (if (nim-info-docstring-p syntax-ppss)
          font-lock-doc-face
        font-lock-comment-face)
    font-lock-string-face))

(defun nim-nav--beginning-of-defun (&optional arg)
  "Internal implementation of `nim-nav-beginning-of-defun'.
With positive ARG search backwards, else search forwards."
  (when (or (null arg) (= arg 0)) (setq arg 1))
  (let* ((re-search-fn (if (> arg 0)
                           #'re-search-backward
                         #'re-search-forward))
         (line-beg-pos (line-beginning-position))
         (line-content-start (+ line-beg-pos (current-indentation)))
         (pos (point-marker))
         (beg-indentation
          (and (> arg 0)
               (save-excursion
                 (while (and
                         (not (nim-info-looking-at-beginning-of-defun))
                         (nim-nav-backward-block)))
                 (or (and (nim-info-looking-at-beginning-of-defun)
                          (+ (current-indentation) nim-indent-offset))
                     0))))
         (found
          (progn
            (when (and (< arg 0)
                       (nim-info-looking-at-beginning-of-defun))
              (end-of-line 1))
            (while (and (funcall re-search-fn
                                 nim-nav-beginning-of-defun-regexp nil t)
                        (or (nim-syntax-context-type)
                            ;; Handle nested defuns when moving
                            ;; backwards by checking indentation.
                            (and (> arg 0)
                                 (not (= (current-indentation) 0))
                                 (>= (current-indentation) beg-indentation)))))
            (and (nim-info-looking-at-beginning-of-defun)
                 (or (not (= (line-number-at-pos pos)
                             (line-number-at-pos)))
                     (and (>= (point) line-beg-pos)
                          (<= (point) line-content-start)
                          (> pos line-content-start)))))))
    (if found
        (or (beginning-of-line 1) t)
      (and (goto-char pos) nil))))

(defun nim-nav-beginning-of-defun (&optional arg)
  "Move point to `beginning-of-defun'.
With positive ARG search backwards else search forward.
ARG nil or 0 defaults to 1.  When searching backwards,
nested defuns are handled with care depending on current
point position.  Return non-nil if point is moved to
`beginning-of-defun'."
  (when (or (null arg) (= arg 0)) (setq arg 1))
  (let ((found))
    (while (and (not (= arg 0))
                (let ((keep-searching-p
                       (nim-nav--beginning-of-defun arg)))
                  (when (and keep-searching-p (null found))
                    (setq found t))
                  keep-searching-p))
      (setq arg (if (> arg 0) (1- arg) (1+ arg))))
    found))

(defun nim-nav-end-of-defun ()
  "Move point to the end of def or class.
Returns nil if point is not in a def or class."
  (interactive)
  (let ((beg-defun-indent)
        (beg-pos (point)))
    (when (or (nim-info-looking-at-beginning-of-defun)
              (nim-nav-beginning-of-defun 1)
              (nim-nav-beginning-of-defun -1))
      (setq beg-defun-indent (current-indentation))
      (while (progn
               (nim-nav-end-of-statement)
               (nim-util-forward-comment 1)
               (and (> (current-indentation) beg-defun-indent)
                    (not (eobp)))))
      (nim-util-forward-comment -1)
      (forward-line 1)
      ;; Ensure point moves forward.
      (and (> beg-pos (point)) (goto-char beg-pos)))))

(defun nim-nav--syntactically (fn poscompfn &optional contextfn)
  "Move point using FN avoiding places with specific context.
FN must take no arguments.  POSCOMPFN is a two arguments function
used to compare current and previous point after it is moved
using FN, this is normally a less-than or greater-than
comparison.  Optional argument CONTEXTFN defaults to
`nim-syntax-context-type' and is used for checking current
point context, it must return a non-nil value if this point must
be skipped."
  (let ((contextfn (or contextfn 'nim-syntax-context-type))
        (start-pos (point-marker))
        (prev-pos))
    (catch 'found
      (while t
        (let* ((newpos
                (and (funcall fn) (point-marker)))
               (context (funcall contextfn)))
          (cond ((and (not context) newpos
                      (or (and (not prev-pos) newpos)
                          (and prev-pos newpos
                               (funcall poscompfn newpos prev-pos))))
                 (throw 'found (point-marker)))
                ((and newpos context)
                 (setq prev-pos (point)))
                (t (when (not newpos) (goto-char start-pos))
                   (throw 'found nil))))))))

(defun nim-nav--forward-defun (arg)
  "Internal implementation of nim-nav-{backward,forward}-defun.
Uses ARG to define which function to call, and how many times
repeat it."
  (let ((found))
    (while (and (> arg 0)
                (setq found
                      (nim-nav--syntactically
                       (lambda ()
                         (re-search-forward
                          nim-nav-beginning-of-defun-regexp nil t))
                       '>)))
      (setq arg (1- arg)))
    (while (and (< arg 0)
                (setq found
                      (nim-nav--syntactically
                       (lambda ()
                         (re-search-backward
                          nim-nav-beginning-of-defun-regexp nil t))
                       '<)))
      (setq arg (1+ arg)))
    found))

(defun nim-nav-backward-defun (&optional arg)
  "Navigate to closer defun backward ARG times.
Unlikely `nim-nav-beginning-of-defun' this doesn't care about
nested definitions."
  (interactive "^p")
  (nim-nav--forward-defun (- (or arg 1))))

(defun nim-nav-forward-defun (&optional arg)
  "Navigate to closer defun forward ARG times.
Unlikely `nim-nav-beginning-of-defun' this doesn't care about
nested definitions."
  (interactive "^p")
  (nim-nav--forward-defun (or arg 1)))

(defun nim-nav-beginning-of-statement ()
  "Move to start of current statement."
  (interactive "^")
  (back-to-indentation)
  (let* ((ppss (syntax-ppss))
         (context-point
          (or
           (nim-syntax-context 'paren ppss)
           (nim-syntax-context 'string ppss))))
    (cond ((bobp))
          (context-point
           (goto-char context-point)
           (nim-nav-beginning-of-statement))
          ((save-excursion
             (forward-line -1)
             (nim-info-line-ends-backslash-p))
           (forward-line -1)
           (nim-nav-beginning-of-statement))))
  (point-marker))

(defun nim-nav-end-of-statement (&optional noend)
  "Move to end of current statement.
Optional argument NOEND is internal and makes the logic to not
jump to the end of line when moving forward searching for the end
of the statement."
  (interactive "^")
  (let (string-start bs-pos)
    (while (and (or noend (goto-char (line-end-position)))
                (not (eobp))
                (cond ((setq string-start (nim-syntax-context 'string))
                       (goto-char string-start)
                       (if (nim-syntax-context 'paren)
                           ;; Ended up inside a paren, roll again.
                           (nim-nav-end-of-statement t)
                         ;; This is not inside a paren, move to the
                         ;; end of this string.
                         (goto-char (+ (point)
                                       (nim-syntax-count-quotes
                                        (char-after (point)) (point))))
                         (or (re-search-forward (rx (syntax string-delimiter)) nil t)
                             (goto-char (point-max)))))
                      ((nim-syntax-context 'paren)
                       ;; The statement won't end before we've escaped
                       ;; at least one level of parenthesis.
                       (condition-case err
                           (goto-char (scan-lists (point) 1 -1))
                         (scan-error (goto-char (nth 3 err)))))
                      ((setq bs-pos (nim-info-line-ends-backslash-p))
                       (goto-char bs-pos)
                       (forward-line 1))))))
  (point-marker))

(defun nim-nav-backward-statement (&optional arg)
  "Move backward to previous statement.
With ARG, repeat.  See `nim-nav-forward-statement'."
  (interactive "^p")
  (or arg (setq arg 1))
  (nim-nav-forward-statement (- arg)))

(defun nim-nav-forward-statement (&optional arg)
  "Move forward to next statement.
With ARG, repeat.  With negative argument, move ARG times
backward to previous statement."
  (interactive "^p")
  (or arg (setq arg 1))
  (while (> arg 0)
    (nim-nav-end-of-statement)
    (nim-util-forward-comment)
    (nim-nav-beginning-of-statement)
    (setq arg (1- arg)))
  (while (< arg 0)
    (nim-nav-beginning-of-statement)
    (nim-util-forward-comment -1)
    (nim-nav-beginning-of-statement)
    (setq arg (1+ arg))))

(defun nim-nav-beginning-of-block ()
  "Move to start of current block."
  (interactive "^")
  (let ((starting-pos (point)))
    (if (progn
          (nim-nav-beginning-of-statement)
          (looking-at (nim-rx block-start)))
        (point-marker)
      ;; Go to first line beginning a statement
      (while (and (not (bobp))
                  (or (and (nim-nav-beginning-of-statement) nil)
                      (nim-info-current-line-comment-p)
                      (nim-info-current-line-empty-p)))
        (forward-line -1))
      (let ((block-matching-indent
             (- (current-indentation) nim-indent-offset)))
        (while
            (and (nim-nav-backward-block)
                 (> (current-indentation) block-matching-indent)))
        (if (and (looking-at (nim-rx block-start))
                 (= (current-indentation) block-matching-indent))
            (point-marker)
          (and (goto-char starting-pos) nil))))))

(defun nim-nav-end-of-block ()
  "Move to end of current block."
  (interactive "^")
  (when (nim-nav-beginning-of-block)
    (let ((block-indentation (current-indentation)))
      (nim-nav-end-of-statement)
      (while (and (forward-line 1)
                  (not (eobp))
                  (or (and (> (current-indentation) block-indentation)
                           (or (nim-nav-end-of-statement) t))
                      (nim-info-current-line-comment-p)
                      (nim-info-current-line-empty-p))))
      (nim-util-forward-comment -1)
      (point-marker))))

(defun nim-nav-backward-block (&optional arg)
  "Move backward to previous block of code.
With ARG, repeat.  See `nim-nav-forward-block'."
  (interactive "^p")
  (or arg (setq arg 1))
  (nim-nav-forward-block (- arg)))

(defun nim-nav-forward-block (&optional arg)
  "Move forward to next block of code.
With ARG, repeat.  With negative argument, move ARG times
backward to previous block."
  (interactive "^p")
  (or arg (setq arg 1))
  (let ((block-start-regexp
         (nim-rx line-start (* whitespace) block-start))
        (starting-pos (point)))
    (while (> arg 0)
      (nim-nav-end-of-statement)
      (while (and
              (re-search-forward block-start-regexp nil t)
              (nim-syntax-context-type)))
      (setq arg (1- arg)))
    (while (< arg 0)
      (nim-nav-beginning-of-statement)
      (while (and
              (re-search-backward block-start-regexp nil t)
              (nim-syntax-context-type)))
      (setq arg (1+ arg)))
    (nim-nav-beginning-of-statement)
    (if (not (looking-at (nim-rx block-start)))
        (and (goto-char starting-pos) nil)
      (and (not (= (point) starting-pos)) (point-marker)))))

(defun nim-nav--lisp-forward-sexp (&optional arg)
  "Standard version `forward-sexp'.
It ignores completely the value of `forward-sexp-function' by
setting it to nil before calling `forward-sexp'.  With positive
ARG move forward only one sexp, else move backwards."
  (let ((forward-sexp-function)
        (arg (if (or (not arg) (> arg 0)) 1 -1)))
    (forward-sexp arg)))

(defun nim-nav--lisp-forward-sexp-safe (&optional arg)
  "Safe version of standard `forward-sexp'.
When at end of sexp (i.e. looking at a opening/closing paren)
skips it instead of throwing an error.  With positive ARG move
forward only one sexp, else move backwards."
  (let* ((arg (if (or (not arg) (> arg 0)) 1 -1))
         (paren-regexp
          (if (> arg 0) (nim-rx close-paren) (nim-rx open-paren)))
         (search-fn
          (if (> arg 0) #'re-search-forward #'re-search-backward)))
    (condition-case nil
        (nim-nav--lisp-forward-sexp arg)
      (error
       (while (and (funcall search-fn paren-regexp nil t)
                   (nim-syntax-context 'paren)))))))

(defun nim-nav--forward-sexp (&optional dir safe skip-parens-p)
  "Move to forward sexp.
With positive optional argument DIR direction move forward, else
backwards.  When optional argument SAFE is non-nil do not throw
errors when at end of sexp, skip it instead.  With optional
argument SKIP-PARENS-P force sexp motion to ignore parenthesized
expressions when looking at them in either direction."
  (setq dir (or dir 1))
  (unless (= dir 0)
    (let* ((forward-p (if (> dir 0)
                          (and (setq dir 1) t)
                        (and (setq dir -1) nil)))
           (context-type (nim-syntax-context-type)))
      (cond
       ((memq context-type '(string comment))
        ;; Inside of a string, get out of it.
        (let ((forward-sexp-function))
          (forward-sexp dir)))
       ((and (not skip-parens-p)
             (or (eq context-type 'paren)
                 (if forward-p
                     (eq (syntax-class (syntax-after (point)))
                         (car (string-to-syntax "(")))
                   (eq (syntax-class (syntax-after (1- (point))))
                       (car (string-to-syntax ")"))))))
        ;; Inside a paren or looking at it, lisp knows what to do.
        (if safe
            (nim-nav--lisp-forward-sexp-safe dir)
          (nim-nav--lisp-forward-sexp dir)))
       (t
        ;; This part handles the lispy feel of
        ;; `nim-nav-forward-sexp'.  Knowing everything about the
        ;; current context and the context of the next sexp tries to
        ;; follow the lisp sexp motion commands in a symmetric manner.
        (let* ((context
                (cond
                 ((nim-info-beginning-of-block-p) 'block-start)
                 ((nim-info-end-of-block-p) 'block-end)
                 ((nim-info-beginning-of-statement-p) 'statement-start)
                 ((nim-info-end-of-statement-p) 'statement-end)))
               (next-sexp-pos
                (save-excursion
                  (if safe
                      (nim-nav--lisp-forward-sexp-safe dir)
                    (nim-nav--lisp-forward-sexp dir))
                  (point)))
               (next-sexp-context
                (save-excursion
                  (goto-char next-sexp-pos)
                  (cond
                   ((nim-info-beginning-of-block-p) 'block-start)
                   ((nim-info-end-of-block-p) 'block-end)
                   ((nim-info-beginning-of-statement-p) 'statement-start)
                   ((nim-info-end-of-statement-p) 'statement-end)
                   ((nim-info-statement-starts-block-p) 'starts-block)
                   ((nim-info-statement-ends-block-p) 'ends-block)))))
          (if forward-p
              (cond ((and (not (eobp))
                          (nim-info-current-line-empty-p))
                     (nim-util-forward-comment dir)
                     (nim-nav--forward-sexp dir safe skip-parens-p))
                    ((eq context 'block-start)
                     (nim-nav-end-of-block))
                    ((eq context 'statement-start)
                     (nim-nav-end-of-statement))
                    ((and (memq context '(statement-end block-end))
                          (eq next-sexp-context 'ends-block))
                     (goto-char next-sexp-pos)
                     (nim-nav-end-of-block))
                    ((and (memq context '(statement-end block-end))
                          (eq next-sexp-context 'starts-block))
                     (goto-char next-sexp-pos)
                     (nim-nav-end-of-block))
                    ((memq context '(statement-end block-end))
                     (goto-char next-sexp-pos)
                     (nim-nav-end-of-statement))
                    (t (goto-char next-sexp-pos)))
            (cond ((and (not (bobp))
                        (nim-info-current-line-empty-p))
                   (nim-util-forward-comment dir)
                   (nim-nav--forward-sexp dir safe skip-parens-p))
                  ((eq context 'block-end)
                   (nim-nav-beginning-of-block))
                  ((eq context 'statement-end)
                   (nim-nav-beginning-of-statement))
                  ((and (memq context '(statement-start block-start))
                        (eq next-sexp-context 'starts-block))
                   (goto-char next-sexp-pos)
                   (nim-nav-beginning-of-block))
                  ((and (memq context '(statement-start block-start))
                        (eq next-sexp-context 'ends-block))
                   (goto-char next-sexp-pos)
                   (nim-nav-beginning-of-block))
                  ((memq context '(statement-start block-start))
                   (goto-char next-sexp-pos)
                   (nim-nav-beginning-of-statement))
                  (t (goto-char next-sexp-pos))))))))))

(defun nim-nav-forward-sexp (&optional arg safe skip-parens-p)
  "Move forward across expressions.
With ARG, do it that many times.  Negative arg -N means move
backward N times.  When optional argument SAFE is non-nil do not
throw errors when at end of sexp, skip it instead.  With optional
argument SKIP-PARENS-P force sexp motion to ignore parenthesized
expressions when looking at them in either direction (forced to t
in interactive calls)."
  (interactive "^p")
  (or arg (setq arg 1))
  ;; Do not follow parens on interactive calls.  This hack to detect
  ;; if the function was called interactively copes with the way
  ;; `forward-sexp' works by calling `forward-sexp-function', losing
  ;; interactive detection by checking `current-prefix-arg'.  The
  ;; reason to make this distinction is that lisp functions like
  ;; `blink-matching-open' get confused causing issues like the one in
  ;; Bug#16191.  With this approach the user gets a symmetric behavior
  ;; when working interactively while called functions expecting
  ;; paren-based sexp motion work just fine.
  (or
   skip-parens-p
   (setq skip-parens-p
         (memq real-this-command
               (list
                #'forward-sexp #'backward-sexp
                #'nim-nav-forward-sexp #'nim-nav-backward-sexp
                #'nim-nav-forward-sexp-safe #'nim-nav-backward-sexp))))
  (while (> arg 0)
    (nim-nav--forward-sexp 1 safe skip-parens-p)
    (setq arg (1- arg)))
  (while (< arg 0)
    (nim-nav--forward-sexp -1 safe skip-parens-p)
    (setq arg (1+ arg))))

(defun nim-nav-backward-sexp (&optional arg safe skip-parens-p)
  "Move backward across expressions.
With ARG, do it that many times.  Negative arg -N means move
forward N times.  When optional argument SAFE is non-nil do not
throw errors when at end of sexp, skip it instead.  With optional
argument SKIP-PARENS-P force sexp motion to ignore parenthesized
expressions when looking at them in either direction (forced to t
in interactive calls)."
  (interactive "^p")
  (or arg (setq arg 1))
  (nim-nav-forward-sexp (- arg) safe skip-parens-p))

(defun nim-nav-forward-sexp-safe (&optional arg skip-parens-p)
  "Move forward safely across expressions.
With ARG, do it that many times.  Negative arg -N means move
backward N times.  With optional argument SKIP-PARENS-P force
sexp motion to ignore parenthesized expressions when looking at
them in either direction (forced to t in interactive calls)."
  (interactive "^p")
  (nim-nav-forward-sexp arg t skip-parens-p))

(defun nim-nav-backward-sexp-safe (&optional arg skip-parens-p)
  "Move backward safely across expressions.
With ARG, do it that many times.  Negative arg -N means move
forward N times.  With optional argument SKIP-PARENS-P force sexp
motion to ignore parenthesized expressions when looking at them in
either direction (forced to t in interactive calls)."
  (interactive "^p")
  (nim-nav-backward-sexp arg t skip-parens-p))

(defun nim-nav--up-list (&optional dir)
  "Internal implementation of `nim-nav-up-list'.
DIR is always 1 or -1 and comes sanitized from
`nim-nav-up-list' calls."
  (let ((context (nim-syntax-context-type))
        (forward-p (> dir 0)))
    (cond
     ((memq context '(string comment)))
     ((eq context 'paren)
      (let ((forward-sexp-function))
        (up-list dir)))
     ((and forward-p (nim-info-end-of-block-p))
      (let ((parent-end-pos
             (save-excursion
               (let ((indentation (and
                                   (nim-nav-beginning-of-block)
                                   (current-indentation))))
                 (while (and indentation
                             (> indentation 0)
                             (>= (current-indentation) indentation)
                             (nim-nav-backward-block)))
                 (nim-nav-end-of-block)))))
        (and (> (or parent-end-pos (point)) (point))
             (goto-char parent-end-pos))))
     (forward-p (nim-nav-end-of-block))
     ((and (not forward-p)
           (> (current-indentation) 0)
           (nim-info-beginning-of-block-p))
      (let ((prev-block-pos
             (save-excursion
               (let ((indentation (current-indentation)))
                 (while (and (nim-nav-backward-block)
                             (>= (current-indentation) indentation))))
               (point))))
        (and (> (point) prev-block-pos)
             (goto-char prev-block-pos))))
     ((not forward-p) (nim-nav-beginning-of-block)))))

(defun nim-nav-up-list (&optional arg)
  "Move forward out of one level of parentheses (or blocks).
With ARG, do this that many times.
A negative argument means move backward but still to a less deep spot.
This command assumes point is not in a string or comment."
  (interactive "^p")
  (or arg (setq arg 1))
  (while (> arg 0)
    (nim-nav--up-list 1)
    (setq arg (1- arg)))
  (while (< arg 0)
    (nim-nav--up-list -1)
    (setq arg (1+ arg))))

(defun nim-nav-backward-up-list (&optional arg)
  "Move backward out of one level of parentheses (or blocks).
With ARG, do this that many times.
A negative argument means move forward but still to a less deep spot.
This command assumes point is not in a string or comment."
  (interactive "^p")
  (or arg (setq arg 1))
  (nim-nav-up-list (- arg)))

(defun nim-nav-if-name-main ()
  "Move point at the beginning the __main__ block.
When \"if __name__ == '__main__':\" is found returns its
position, else returns nil."
  (interactive)
  (let ((point (point))
        (found (catch 'found
                 (goto-char (point-min))
                 (while (re-search-forward
                         (nim-rx line-start
                                    "if" (+ space)
                                    "__name__" (+ space)
                                    "==" (+ space)
                                    (group-n 1 (or ?\" ?\'))
                                    "__main__" (backref 1) (* space) ":")
                         nil t)
                   (when (not (nim-syntax-context-type))
                     (beginning-of-line)
                     (throw 'found t))))))
    (if found
        (point)
      (ignore (goto-char point)))))

(defun nim-info-current-defun (&optional include-type)
  "Return name of surrounding function with Nim compatible dotty syntax.
Optional argument INCLUDE-TYPE indicates to include the type of the defun.
This function can be used as the value of `add-log-current-defun-function'
since it returns nil if point is not inside a defun."
  (save-restriction
    (widen)
    (save-excursion
      (end-of-line 1)
      (let ((names)
            (starting-indentation (current-indentation))
            (starting-pos (point))
            (first-run t)
            (last-indent)
            (type))
        (catch 'exit
          (while (nim-nav-beginning-of-defun 1)
            (when (save-match-data
                    (and
                     (or (not last-indent)
                         (< (current-indentation) last-indent))
                     (or
                      (and first-run
                           (save-excursion
                             ;; If this is the first run, we may add
                             ;; the current defun at point.
                             (setq first-run nil)
                             (goto-char starting-pos)
                             (nim-nav-beginning-of-statement)
                             (beginning-of-line 1)
                             (looking-at-p
                              nim-nav-beginning-of-defun-regexp)))
                      (< starting-pos
                         (save-excursion
                           (let ((min-indent
                                  (+ (current-indentation)
                                     nim-indent-offset)))
                             (if (< starting-indentation  min-indent)
                                 ;; If the starting indentation is not
                                 ;; within the min defun indent make the
                                 ;; check fail.
                                 starting-pos
                               ;; Else go to the end of defun and add
                               ;; up the current indentation to the
                               ;; ending position.
                               (nim-nav-end-of-defun)
                               (+ (point)
                                  (if (>= (current-indentation) min-indent)
                                      (1+ (current-indentation))
                                    0)))))))))
              (save-match-data (setq last-indent (current-indentation)))
              (if (or (not include-type) type)
                  (setq names (cons (match-string-no-properties 1) names))
                (let ((match (split-string (match-string-no-properties 0))))
                  (setq type (car match))
                  (setq names (cons (cadr match) names)))))
            ;; Stop searching ASAP.
            (and (= (current-indentation) 0) (throw 'exit t))))
        (and names
             (concat (and type (format "%s " type))
                     (mapconcat 'identity names ".")))))))

(defun nim-info-current-symbol (&optional replace-self)
  "Return current symbol using dotty syntax.
With optional argument REPLACE-SELF convert \"self\" to current
parent defun name."
  (let ((name
         (and (not (nim-syntax-comment-or-string-p))
              (with-syntax-table nim-dotty-syntax-table
                (let ((sym (symbol-at-point)))
                  (and sym
                       (substring-no-properties (symbol-name sym))))))))
    (when name
      (if (not replace-self)
          name
        (let ((current-defun (nim-info-current-defun)))
          (if (not current-defun)
              name
            (replace-regexp-in-string
             (nim-rx line-start word-start "self" word-end ?.)
             (concat
              (mapconcat 'identity
                         (butlast (split-string current-defun "\\."))
                         ".") ".")
             name)))))))

(defun nim-info-statement-starts-block-p ()
  "Return non-nil if current statement opens a block."
  (save-excursion
    (nim-nav-beginning-of-statement)
    (looking-at (nim-rx block-start))))

(defun nim-info-statement-ends-block-p ()
  "Return non-nil if point is at end of block."
  (let ((end-of-block-pos (save-excursion
                            (nim-nav-end-of-block)))
        (end-of-statement-pos (save-excursion
                                (nim-nav-end-of-statement))))
    (and end-of-block-pos end-of-statement-pos
         (= end-of-block-pos end-of-statement-pos))))

(defun nim-info-beginning-of-statement-p ()
  "Return non-nil if point is at beginning of statement."
  (= (point) (save-excursion
               (nim-nav-beginning-of-statement)
               (point))))

(defun nim-info-end-of-statement-p ()
  "Return non-nil if point is at end of statement."
  (= (point) (save-excursion
               (nim-nav-end-of-statement)
               (point))))

(defun nim-info-beginning-of-block-p ()
  "Return non-nil if point is at beginning of block."
  (and (nim-info-beginning-of-statement-p)
       (nim-info-statement-starts-block-p)))

(defun nim-info-end-of-block-p ()
  "Return non-nil if point is at end of block."
  (and (nim-info-end-of-statement-p)
       (nim-info-statement-ends-block-p)))

(define-obsolete-function-alias
  'nim-info-closing-block
  'nim-info-dedenter-opening-block-position "24.4")

(defun nim-info-dedenter-opening-block-position ()
  "Return the point of the closest block the current line closes.
Returns nil if point is not on a dedenter statement or no opening
block can be detected.  The latter case meaning current file is
likely an invalid nim file."
  (let ((positions (nim-info-dedenter-opening-block-positions))
        (indentation (current-indentation))
        (position))
    (while (and (not position)
                positions)
      (save-excursion
        (goto-char (car positions))
        (if (<= (current-indentation) indentation)
            (setq position (car positions))
          (setq positions (cdr positions)))))
    position))

(defun nim-info-dedenter-opening-block-positions ()
  "Return points of blocks the current line may close sorted by closer.
Returns nil if point is not on a dedenter statement or no opening
block can be detected.  The latter case meaning current file is
likely an invalid nim file."
  (save-excursion
    (let ((dedenter-pos (nim-info-dedenter-statement-p)))
      (when dedenter-pos
        (goto-char dedenter-pos)
        (let* ((pairs '(("elif" "elif" "if" "of" "case" "when")
                        ("of" "of" "case")
                        ("else" "if" "elif" "except" "for" "while" "of" "when")
                        ("except" "except" "try")
                        ("finally" "else" "except" "try")))
               (dedenter (match-string-no-properties 0))
               (possible-opening-blocks (cdr (assoc-string dedenter pairs)))
               (collected-indentations)
               (opening-blocks))
          (catch 'exit
            (while (nim-nav--syntactically
                    (lambda ()
                      (re-search-backward (nim-rx block-start) nil t))
                    #'<)
              (let ((indentation (current-indentation)))
                (when (and (not (memq indentation collected-indentations))
                           (or (not collected-indentations)
                               (< indentation (apply #'min collected-indentations))))
                  (setq collected-indentations
                        (cons indentation collected-indentations))
                  (when (member (match-string-no-properties 0)
                                possible-opening-blocks)
                    (setq opening-blocks (cons (point) opening-blocks))))
                (when (zerop indentation)
                  (throw 'exit nil)))))
          ;; sort by closer
          (nreverse opening-blocks))))))

(define-obsolete-function-alias
  'nim-info-closing-block-message
  'nim-info-dedenter-opening-block-message "24.4")

(defun nim-info-dedenter-opening-block-message  ()
  "Message the first line of the block the current statement closes."
  (let ((point (nim-info-dedenter-opening-block-position)))
    (when point
      (save-restriction
        (widen)
        (unless noninteractive ; prevent output message during testing
          (message "Closes %s" (save-excursion
                                 (goto-char point)
                                 (buffer-substring
                                  (point) (line-end-position)))))))))

(defun nim-info-dedenter-statement-p ()
  "Return point if current statement is a dedenter.
Sets `match-data' to the keyword that starts the dedenter
statement."
  (save-excursion
    (nim-nav-beginning-of-statement)
    (when (and (not (nim-syntax-context-type))
               (looking-at (nim-rx dedenter)))
      (point))))

(defun nim-info-line-ends-backslash-p (&optional line-number)
  "Return non-nil if current line ends with backslash.
With optional argument LINE-NUMBER, check that line instead."
  (save-excursion
    (save-restriction
      (widen)
      (when line-number
        (nim-util-goto-line line-number))
      (while (and (not (eobp))
                  (goto-char (line-end-position))
                  (nim-syntax-context 'paren)
                  (not (equal (char-before (point)) ?\\)))
        (forward-line 1))
      (when (equal (char-before) ?\\)
        (point-marker)))))

(defun nim-info-beginning-of-backslash (&optional line-number)
  "Return the point where the backslashed line start.
Optional argument LINE-NUMBER forces the line number to check against."
  (save-excursion
    (save-restriction
      (widen)
      (when line-number
        (nim-util-goto-line line-number))
      (when (nim-info-line-ends-backslash-p)
        (while (save-excursion
                 (goto-char (line-beginning-position))
                 (nim-syntax-context 'paren))
          (forward-line -1))
        (back-to-indentation)
        (point-marker)))))

(defun nim-info-continuation-line-p ()
  "Check if current line is continuation of another.
When current line is continuation of another return the point
where the continued line ends."
  (save-excursion
    (save-restriction
      (widen)
      (let* ((context-type (progn
                             (back-to-indentation)
                             (nim-syntax-context-type)))
             (line-start (line-number-at-pos))
             (context-start (when context-type
                              (nim-syntax-context context-type))))
        (cond ((equal context-type 'paren)
               ;; Lines inside a paren are always a continuation line
               ;; (except the first one).
               (nim-util-forward-comment -1)
               (point-marker))
              ((member context-type '(string comment))
               ;; move forward an roll again
               (goto-char context-start)
               (nim-util-forward-comment)
               (nim-info-continuation-line-p))
              (t
               ;; Not within a paren, string or comment, the only way
               ;; we are dealing with a continuation line is that
               ;; previous line contains a backslash, and this can
               ;; only be the previous line from current
               (back-to-indentation)
               (nim-util-forward-comment -1)
               (when (and (equal (1- line-start) (line-number-at-pos))
                          (nim-info-line-ends-backslash-p))
                 (point-marker))))))))

(defun nim-info-block-continuation-line-p ()
  "Return non-nil if current line is a continuation of a block."
  (save-excursion
    (when (nim-info-continuation-line-p)
      (forward-line -1)
      (back-to-indentation)
      (when (looking-at (nim-rx block-start))
        (point-marker)))))

(defun nim-info-assignment-statement-p (&optional current-line-only)
  "Check if current line is an assignment.
With argument CURRENT-LINE-ONLY is non-nil, don't follow any
continuations, just check the if current line is an assignment."
  (save-excursion
    (let ((found nil))
      (if current-line-only
          (back-to-indentation)
        (nim-nav-beginning-of-statement))
      (while (and
              (re-search-forward (nim-rx not-simple-operator
                                            assignment-operator
                                            (group not-simple-operator))
                                 (line-end-position) t)
              (not found))
        (save-excursion
          ;; The assignment operator should not be inside a string.
          (backward-char (length (match-string-no-properties 1)))
          (setq found (not (nim-syntax-context-type)))))
      (when found
        (skip-syntax-forward " ")
        (point-marker)))))

;; TODO: rename to clarify this is only for the first continuation
;; line or remove it and move its body to `nim-indent-context'.
(defun nim-info-assignment-continuation-line-p ()
  "Check if current line is the first continuation of an assignment.
When current line is continuation of another with an assignment
return the point of the first non-blank character after the
operator."
  (save-excursion
    (when (nim-info-continuation-line-p)
      (forward-line -1)
      (nim-info-assignment-statement-p t))))

(defun nim-info-looking-at-beginning-of-defun (&optional syntax-ppss)
  "Check if point is at `beginning-of-defun' using SYNTAX-PPSS."
  (and (not (nim-syntax-context-type (or syntax-ppss (syntax-ppss))))
       (save-excursion
         (beginning-of-line 1)
         (looking-at nim-nav-beginning-of-defun-regexp))))

(defun nim-info-current-line-comment-p (&optional line)
  "Return non-nil if current line's start position is comment.
If there is the optional LINE argument, moves LINE times from current line."
  (save-excursion
    (when line (forward-line line))
    (eq ?# (char-after (+ (line-beginning-position) (current-indentation))))))

(defun nim-info-current-line-empty-p (&optional line)
  "Return non-nil if current line is empty, ignoring whitespace.
If there is the optional LINE argument, moves LINE times from current line."
  (save-excursion
    (when line (forward-line line))
    (beginning-of-line 1)
    (looking-at
     (nim-rx line-start (* whitespace)
                (group (* not-newline))
                (* whitespace) line-end))
    (string-equal "" (match-string-no-properties 1))))

(defun nim-info-docstring-p (&optional syntax-ppss)
  "Return non-nil if point is in a docstring.
When optional argument SYNTAX-PPSS is given, use that instead of
point's current `syntax-ppss'."
  (let ((ppss (or syntax-ppss (syntax-ppss))))
    (and (eq ?# (char-before (1+  (nth 8 ppss))))
         (eq ?# (char-before (+ 2 (nth 8 ppss)))))))

(defun nim-info-encoding-from-cookie ()
  "Detect current buffer's encoding from its coding cookie.
Returns the encoding as a symbol."
  (let ((first-two-lines
         (save-excursion
           (save-restriction
             (widen)
             (goto-char (point-min))
             (forward-line 2)
             (buffer-substring-no-properties
              (point)
              (point-min))))))
    (when (string-match (nim-rx coding-cookie) first-two-lines)
      (intern (match-string-no-properties 1 first-two-lines)))))

(defun nim-info-encoding ()
  "Return encoding for file.
Try `nim-info-encoding-from-cookie', if none is found then
default to utf-8."
  ;; If no encoding is defined, then it's safe to use UTF-8: Nim 2
  ;; uses ASCII as default while Nim 3 uses UTF-8.  This means that
  ;; in the worst case scenario nim.el will make things work for
  ;; Nim 2 files with unicode data and no encoding defined.
  (or (nim-info-encoding-from-cookie)
      'utf-8))

(defun nim-helper-line-contain-p (char &optional pos)
  "Return non-nil if the current line has CHAR.
But, string-face's CHAR is ignored.  If you set POS, the check starts from POS."
  (save-excursion
    (catch 'exit
      (when pos (goto-char pos))
      (while (not (eolp))
        (let ((ppss (syntax-ppss)))
          (when (and (not (nth 3 ppss))
                     (not (nth 4 ppss))
                     (eq char (char-after (point))))
            (throw 'exit (point)))
          (forward-char))))))

(provide 'nim-helper)
;;; nim-helper.el ends here
