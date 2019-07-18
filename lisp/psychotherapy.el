;;; psychotherapy.el --- org-capture template for dysfunctional thoughts -*- lexical-binding: t; -*-
;;; Commentary:

;; This package provide an org-capture template for recording and
;; processing dysfunctional thoughts.  This method was taken from
;; David D. Burns’s book Feeling Good: The New Mood Therapy.

;; I don’t use it anymore, but this was nice project to investigate
;; how org-capture and helm could be used together to make a fillable
;; form in which you move through the steps with a single key-binding
;; (here C-c C-c).

;;; Code:

;;; helm-smbp
;; smbp stands for ‘Setting Multiple Boolean Properties’

;;----------------------------------------------------------------------------
;; Helper functions
;;----------------------------------------------------------------------------
(defun zp/make-property-alist (name list)
  "Create property ALIST from LIST designated by SYMBOL.

SYMBOL points to a LIST.

Every ELEM in LIST is formatted as follows:
- Add the name portion of SYMBOL as a prefix
- Make the string uppercase
- Replace spaces and hyphens with underscores"
  (let* ((alist))

    (dolist (var list)
      (add-to-list
       'alist
       ;; Replace spaces and hyphens with underscores
       (cons var (replace-regexp-in-string "-\\| " "_" (upcase (concat name "-" var))))
       t))
    alist))

;;----------------------------------------------------------------------------
;; Helm definition
;;----------------------------------------------------------------------------
(defun zp/helm-smbp-set-property (alist candidate)
  (save-excursion
    (goto-char (org-end-of-subtree))
    (newline)
    (insert "- " (car (rassoc candidate alist))))
  (org-set-property candidate "t")
  (org-cycle nil)
  (org-cycle nil))

(defun zp/helm-smbp-set-properties (alist)
  (save-excursion
    (org-mark-subtree)
    (forward-line)
    (delete-region (region-beginning) (region-end)))
  (mapc (lambda (arg)
          (zp/helm-smbp-set-property alist arg))
        (helm-marked-candidates)))

(defun zp/helm-smbp (symbol)
  (interactive)
  (let* ((symbol-name (symbol-name symbol))
         (list (symbol-value symbol))

         ;; Separate prefix and name in symbol-name
         (prefix-pos    (string-match-p "/" symbol-name))
         (prefix        (if prefix-pos
                            (substring symbol-name 0 prefix-pos)))
         (name  (if prefix-pos
                    (substring symbol-name (1+ prefix-pos))
                  symbol-name))

         (property-alist (zp/make-property-alist name list))

         (set-property (lambda (arg)
                        (zp/helm-smbp-set-properties `,property-alist))))
    (helm :name "Testing"
          :sources `((name . ,(concat "*helm " name "*"))
                     (candidates . ,property-alist)
                     (action . (("Set property" . ,set-property)))))))

;;----------------------------------------------------------------------------
;; Variables
;;----------------------------------------------------------------------------
(defvar zp/emotions nil
  "List of emotions.")

(defvar zp/emotions-alist nil
  "Alist of emotions where the car of each item is the human
  name, and the corresponding cdr is the name of the property.")

(defvar zp/cognitive-distortions nil
  "List of cognitive distortions.")

(defvar zp/cognitive-distortions-alist nil
  "Alist of cognitive distortions where the car of each item is
  the human name, and the corresponding cdr is the name of the
  property.")

;;; Psychotherapy-mode

;;----------------------------------------------------------------------------
;; Helper functions
;;----------------------------------------------------------------------------
(defun zp/psychotherapy-thoughts-has-response-p ()
  "Return t if the current thought has a response."
  (let ((subtree-end (save-excursion (org-end-of-subtree t))))
    (save-excursion
      (unless (org-at-heading-p)
        (org-previous-visible-heading 1))
      (re-search-forward "^\\*+ Cognitive Distortions$" subtree-end t))))

(defun zp/psychotherapy-thoughts-clear-response ()
  (save-excursion
    (org-mark-subtree)
    (forward-line)
    (delete-region (region-beginning) (region-end))))

(defun zp/psychotherapy-thoughts-create-response (arg)
  (let ((org-insert-heading-respect-content t)
        (has-response-p (zp/psychotherapy-thoughts-has-response-p)))
    (if has-response-p
        (zp/psychotherapy-thoughts-clear-response))
    (org-insert-heading)
    (org-demote)
    (insert "Cognitive Distortions")

    (zp/helm-smbp 'zp/cognitive-distortions)

    (org-insert-heading)
    (insert "Rational Response")
    (end-of-line)
    (open-line 1)
    (next-line)
    ))

;;----------------------------------------------------------------------------
;; DWIM components
;;----------------------------------------------------------------------------
;; Instructions
(setq zp/psychotherapy-headings-alist
      '(("Situation" .
         (lambda (arg)
           (if (save-excursion (org-get-next-sibling))
               (progn
                 (org-forward-heading-same-level 1)
                 (zp/psychotherapy-dwim nil)))))

        ("Emotions" .
         (lambda (arg)
           (let ((org-insert-heading-respect-content t))
             (zp/helm-smbp 'zp/emotions)
             (if (save-excursion
                   (org-get-next-sibling))
                 (org-forward-heading-same-level 1))
             (unless (save-excursion
                       (and (org-get-heading "Thoughts")
                            (org-goto-first-child)))
               (org-insert-heading)
               (org-demote)))))

        ("Cognitive Distortions" .
         (lambda (arg)
           (zp/helm-smbp 'zp/cognitive-distortions)
           (if (save-excursion (org-get-next-sibling))
               (org-forward-heading-same-level 1))
           (next-line)))

        ("Rational Response" .
         (lambda (arg)
           (cond ((eq arg 4)
                  (outline-up-heading 1)
                  (zp/psychotherapy-thoughts-create-response arg))
                 ((save-excursion
                    (outline-up-heading 1)
                    (org-get-next-sibling))
                  (outline-up-heading 1)
                  (org-forward-heading-same-level 1)
                  (zp/psychotherapy-dwim nil))
                 (t
                  (if (y-or-n-p "Finalise?")
                      (org-capture-finalize)))))))

      zp/psychotherapy-parent-headings-alist
      '(("Thoughts"     . zp/psychotherapy-thoughts-create-response)))

;; Command
(defun zp/psychotherapy-dwim (arg)
  (interactive "p")
  (let* ((heading (org-get-heading))
         (type (cdr (assoc heading zp/psychotherapy-headings-alist)))
         (parent (car (last (org-get-outline-path))))
         (parent-type (cdr (assoc parent zp/psychotherapy-parent-headings-alist))))
    (cond (type
           (unless (org-at-heading-p)
             (org-previous-visible-heading 1))
           (funcall type arg))

          (parent-type
           (funcall parent-type arg))

          (t
           (if (y-or-n-p "Finalise?")
               (org-capture-finalize))))))

;;----------------------------------------------------------------------------
;; Minor-mode definition
;;----------------------------------------------------------------------------
;; mode definition
(defvar zp/psychotherapy-mode-map
  (let ((map (make-sparse-keymap)))
        (define-key map (kbd "C-c C-c") #'zp/psychotherapy-dwim)
        map)
  "Keymap for ‘zp/psychotherapy-mode’.")

(define-minor-mode zp/psychotherapy-mode
  "Provide bindings for filling psychotherapy forms."
  :lighter " Psy"
  :keymap zp/psychotherapy-mode-map)

;; Loading extra minor-modes with org-capture
(defvar zp/org-capture-extra-minor-modes-alist nil
  "Alist of minors modes to load with specific org-capture templates.")

(setq zp/org-capture-extra-minor-modes-alist
      '(("D" . zp/psychotherapy-mode)))

;;----------------------------------------------------------------------------
;; Hook to org-capture
;;----------------------------------------------------------------------------
(defun zp/org-capture-load-extra-minor-mode ()
  "Load minor-mode based on based on key."
  (interactive)
  (let* ((key (plist-get org-capture-plist :key))
         (minor-mode (cdr (assoc key zp/org-capture-extra-minor-modes-alist))))
    (if minor-mode
        (funcall minor-mode))))

(add-hook 'org-capture-mode-hook #'zp/org-capture-load-extra-minor-mode)

(provide 'psychotherapy)
;;; psychotherapy.el ends here
