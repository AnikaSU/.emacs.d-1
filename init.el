;;; init.el --- Initialization file for Emacs
;;; Commentary: Emacs Startup File --- initialization for Emacs

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; =============  INIT FILE  ==============
;; ================== * ===================
;; =============  ~ Zaeph ~  ==============
;; =============  Dream on.  ==============
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

(setq default-directory "/home/zaeph/")
(setq inhibit-startup-screen 1)
(setq initial-scratch-message ";; Emacs Scratch

")

(setq debug-on-error nil)
(defalias 'yes-or-no-p 'y-or-n-p)

(add-to-list 'load-path "/home/zaeph/.emacs.d/lisp")
(add-to-list 'load-path (expand-file-name "/usr/share/emacs/site-lisp"))

;; ;; outline-minor-mode for viewing init.el
;; (add-hook 'emacs-lisp-mode-hook
;;           (lambda ()
;;             (make-local-variable 'outline-regexp)
;;             (setq outline-regexp "^;;; ")
;;             (make-local-variable 'outline-heading-end-regexp)
;;             (setq outline-heading-end-regexp ":\n")
;;             (outline-minor-mode 1)
;;             ))

;; -nt background off
(defun on-after-init ()
  (unless (display-graphic-p (selected-frame))
    (set-face-background 'default "unspecified-bg" (selected-frame))))
(add-hook 'window-setup-hook 'on-after-init)

;; Force horizontal splitting
(setq split-width-threshold 9999)	;Default: 160
(setq split-width-threshold 160)

;; Enable disabled commands
(setq disabled-command-function nil)

;; Transparency
;; (set-frame-parameter (selected-frame) 'alpha '(95 . 95))
;; (add-to-list 'default-frame-alist '(alpha . (95 . 95)))

;; Temporary fix for helm delays
(when (= emacs-major-version 26)
  (setq x-wait-for-event-timeout nil))



;; ========================================
;; ============== PACKAGES ================
;; ========================================

;; MELPA
(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  ;; Comment/uncomment these two lines to enable/disable MELPA and MELPA Stable as desired
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  (when (< emacs-major-version 24)
    ;; For important compatibility libraries like cl-lib
    (add-to-list 'package-archives '("gnu" . (concat proto "://elpa.gnu.org/packages/")))))
(package-initialize)

;; Load extra files, and search subdirs
(let ((default-directory  "/home/zaeph/.emacs.d/lisp/"))
  (normal-top-level-add-subdirs-to-load-path))
(add-to-list 'load-path "/home/zaeph/.emacs.d/lisp/")

;; Start server
(server-start)

;; Evil
(require 'evil)
(evil-mode 0)
;; (setq evil-toggle-key "M-SPC")
;; (setq evil-default-state 'emacs)
;; (evil-set-initial-state 'help-mode 'emacs)
;; (evil-set-initial-state 'messages-buffer-mode 'emacs)
;; (evil-set-initial-state 'undo-tree-visualizer-mode 'emacs)
;; (evil-set-initial-state 'calendar-mode 'emacs)
;; (evil-set-initial-state 'info-mode 'emacs)

;; EasyPG (for encryption)
(require 'epa-file)
(epa-file-enable)
(setq epg-gpg-program "gpg2")

;; Isearch
(define-key isearch-mode-map (kbd "<backspace>") 'isearch-del-char)

;; Ledger
(autoload 'ledger-mode "ledger-mode" "A major mode for Ledger" t)
(require 'ledger-mode)
;; Using MELPA rather than the one from the built one
;; (add-to-list 'load-path
;;              (expand-file-name "/home/zaeph/builds/ledger/src/ledger-3.1.1/lisp/"))
(add-to-list 'auto-mode-alist '("\\.ledger$" . ledger-mode))

(defvar ledger-use-iso-dates nil)
(defvar ledger-reconcile-default-commodity nil)
(defvar ledger-post-auto-adjust-amounts nil)
(setq ledger-use-iso-dates t
      ledger-reconcile-default-commodity "EUR"
      ;; Testing
      ledger-post-auto-adjust-amounts 1
      ledger-schedule-file "/home/zaeph/org/ledger/main-schedule.ledger.gpg")

(add-hook 'ledger-reconcile-mode-hook #'balance-windows)
;; (setq ledger-reconcile-mode-hook nil)

(defun zp/ledger-close-scheduled ()
  (interactive)
  (if (string-match-p (regexp-quote "*Ledger Schedule*") (buffer-name))
      (progn
	(kill-buffer)
	(other-window -1)
	(delete-other-windows))))
(define-key ledger-mode-map (kbd "S-<backspace>") 'zp/ledger-close-scheduled)

;; -----------------------------------------------------------------------------
;; Patch for inserting an empty line after copied transactions
(defvar ledger-copy-transaction-insert-blank-line-after nil
  "Non-nil means insert blank line after a transaction inserted
  with ‘ledger-copy-transaction-at-point’.")

(defun ledger-copy-transaction-at-point (date)
  "Ask for a new DATE and copy the transaction under point to
that date.  Leave point on the first amount."
  (interactive  (list
                 (ledger-read-date "Copy to date: ")))
  (let* ((extents (ledger-navigate-find-xact-extents (point)))
         (transaction (buffer-substring-no-properties (car extents) (cadr extents)))
         (encoded-date (ledger-parse-iso-date date)))
    (ledger-xact-find-slot encoded-date)
    (insert transaction
            (if ledger-copy-transaction-insert-blank-line-after
                "\n\n"
              "\n"))
    (beginning-of-line -1)
    (ledger-navigate-beginning-of-xact)
    (re-search-forward ledger-iso-date-regexp)
    (replace-match date)
    (ledger-next-amount)
    (if (re-search-forward "[-0-9]")
        (goto-char (match-beginning 0)))))

(setq ledger-copy-transaction-insert-blank-line-after t)


;; Patch for killing transaction
(defun ledger-kill-current-transaction (pos)
  "Delete the transaction surrounging POS."
  (interactive "d")
  (let ((bounds (ledger-navigate-find-xact-extents pos)))
    (kill-region (car bounds) (cadr bounds))))

(define-key ledger-mode-map (kbd "C-c C-d") 'ledger-kill-current-transaction)
;; -----------------------------------------------------------------------------

;; zshrc
(add-to-list 'auto-mode-alist '("\\zshrc\\'" . shell-script-mode))
(add-to-list 'auto-mode-alist '("\\prompt_.*_setup\\'" . shell-script-mode))

;; fish
(add-to-list 'auto-mode-alist '("\\.*.fish\\'" . shell-script-mode))

;; fcitx
;; Disabled because of slow-downs in combination with visual-line-mode
;; (fcitx-aggressive-setup)

;; ox-hugo
(require 'ox-hugo)

;; duplicate-thing
(require 'duplicate-thing)

(global-set-key (kbd "M-U") 'universal-argument)
(define-key universal-argument-map "M-U" 'universal-argument-more)
(global-set-key (kbd "M-J") 'duplicate-thing)

(require 'volatile-highlights)
(volatile-highlights-mode)

(require 'clean-aindent-mode)
(add-hook 'prog-mode-hook 'clean-aindent-mode)
(add-hook 'prog-mode-hook 'zp/whitespace-mode-lines-tail)

(global-set-key (kbd "M-U") 'universal-argument)
(global-set-key (kbd "M-SPC") 'delete-horizontal-space)
(global-set-key (kbd "M-S-SPC") 'just-one-space)
(define-key universal-argument-map "\M-U" 'universal-argument-more)
(global-set-key (kbd "M-J") 'duplicate-thing)

(require 'flycheck)
;; (add-hook 'after-init-hook #'global-flycheck-mode)
(setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))
(setq flycheck-emacs-lisp-load-path 'inherit)

(require 'flycheck-pos-tip)
(flycheck-pos-tip-mode)


;; (add-to-list 'load-path "/home/zaeph/.emacs.d/pkg/emacswiki.org/info+.el")
;; (load "/home/zaeph/.emacs.d/pkg/emacswiki.org/info+.el")
(require 'info+)
;; (define-key Info-mode-map (kbd "<mouse-4>") 'Info-mouse-scroll-up)
;; (define-key Info-mode-map (kbd "<mouse-5>") 'Info-mouse-scroll-down)
(define-key Info-mode-map (kbd "<mouse-4>") 'mwheel-scroll)
(define-key Info-mode-map (kbd "<mouse-5>") 'mwheel-scroll)
(define-key Info-mode-map (kbd "j") 'next-line)
(define-key Info-mode-map (kbd "k") 'previous-line)
;; (define-key Info-mode-map (kbd "h") 'Info-history-back)
;; (define-key Info-mode-map (kbd "l") 'Info-history-forward)

;; dired+
;; (setq diredp-hide-details-initially-flag nil)
;; (require 'dired+)

;; dired-x
(add-hook 'dired-load-hook
          (lambda ()
            (load "dired-x")
            ;; Set dired-x global variables here.  For example:
            ;; (setq dired-guess-shell-gnutar "gtar")
            ;; (setq dired-x-hands-off-my-keys nil)
            ))
(add-hook 'dired-mode-hook
          (lambda ()
            ;; Set dired-x buffer-local variables here.  For example:
            ;; (dired-omit-mode 1)
            ))

(require 'recentf-ext)

(require 'diff-hl)
(global-diff-hl-mode)
(add-hook 'dired-mode-hook 'diff-hl-dired-mode)
(add-hook 'dired-mode-hook 'turn-on-gnus-dired-mode)

(diff-hl-flydiff-mode)

(require 'eyebrowse)
;; (eyebrowse-mode)

(require 'which-key)
(which-key-mode)
(setq which-key-idle-delay 1)

(require 'lilypond-mode)

;; Nov
(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))
(add-to-list 'auto-mode-alist '("\\.mobi\\'" . nov-mode))

;; Anki-Editor
;; (require 'anki-editor)

;; el-patch
(require 'el-patch)



;; ========================================
;; =============== FREE_KEYS ==============
;; ========================================

(require 'free-keys)

(setq free-keys-modifiers '("" "C" "M" "C-M" "H"))



;; ========================================
;; ================ ASPELL ================
;; ========================================

(require 'ispell)

(setq-default ispell-program-name "aspell")

;; Tell ispell.el that ’ can be part of a word.
(setq ispell-local-dictionary-alist
      `((nil "[[:alpha:]]" "[^[:alpha:]]" "['\x2019]" nil ("-B") nil utf-8)
	("english" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "en_US") nil utf-8)
	("british" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "en_GB") nil utf-8)
	("french" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "fr_FR") nil utf-8)))

;; Allow curvy quotes to be considered as regular apostrophe
(setq ispell-local-dictionary-alist
 (quote
  (("english" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "en_US") nil utf-8)
   ("british" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "en_GB") nil utf-8)
   ("french" "[[:alpha:]]" "[^[:alpha:]]" "['’]" t ("-d" "fr_FR") nil utf-8))))

;; Don't send ’ to the subprocess.
(defun endless/replace-apostrophe (args)
  (cons (replace-regexp-in-string
         "’" "'" (car args))
        (cdr args)))
(advice-add #'ispell-send-string :filter-args
            #'endless/replace-apostrophe)

;; Convert ' back to ’ from the subprocess.
(defun endless/replace-quote (args)
  (if (not (derived-mode-p 'org-mode))
      args
    (cons (replace-regexp-in-string
           "'" "’" (car args))
          (cdr args))))
(advice-add #'ispell-parse-output :filter-args
            #'endless/replace-quote)

;; Helm-Ispell
(defvar zp/ispell-completion-data nil)
(setq ispell-dictionary "british"
      zp/ispell-completion-data '(("English" . "british")
				 ("French" . "french")))

(defun zp/ispell-switch-dictionary (candidate)
  (interactive)
  (if (eq candidate ispell-local-dictionary)
      (message "Dictionary is already loaded for this language")
    (ispell-change-dictionary candidate)))

(defun zp/ispell-query-dictionary ()
  (if (not (y-or-n-p "Writing in English? "))
      (ispell-change-dictionary "french")))

(defvar zp/helm-ispell-actions nil)
(setq zp/helm-ispell-actions
      '(("Change dictionary" . zp/ispell-switch-dictionary)))

(defvar zp/helm-source-ispell nil)
(setq zp/helm-source-ispell
      '((name . "*HELM Ispell - Dictionary selection*")
	(candidates . zp/ispell-completion-data)
        (action . zp/helm-ispell-actions)))

(defun zp/helm-ispell ()
  (interactive)
  (let ((current ispell-local-dictionary))
    (helm :sources '(zp/helm-source-ispell))))

(defun zp/helm-ispell-preselect (&optional lang)
  (interactive)
  (let ((current ispell-local-dictionary))
    (helm :sources '(zp/helm-source-ispell)
	  :preselect (if (or
			  (eq lang "French")
			  (eq current nil)
			  (string-match-p current "british"))
			 "French"
		       "English"))))



;; ========================================
;; ================= DEFUN ================
;; ========================================

(defun zp/get-string-from-file (file-path)
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))



;; ========================================
;; ================= ERC ==================
;; ========================================

(require 'erc)
(setq erc-autojoin-timing 'connect
      erc-autojoin-channels-alist
      '(("freenode.net" "#emacs" "#ranger")
	("myanonamouse.net" "#anonamouse.net" "#am-members"))
      erc-join-buffer 'bury
      erc-fill-function 'erc-fill-static
      erc-fill-static-center 22
      erc-hide-list '("JOIN" "PART" "QUIT")
      erc-lurker-hide-list '("JOIN" "PART" "QUIT")
      erc-lurker-threshold-time 43200
      erc-prompt-for-nickserv-password nil
      erc-server-reconnect-attempts 5
      erc-server-reconnect-timeout 3
      erc-track-exclude-types '("JOIN" "MODE" "NICK" "PART" "QUIT"
				 "324" "329" "332" "333" "353" "477"))

(add-to-list 'erc-modules 'notify)
(add-to-list 'erc-modules 'notifications)
(erc-update-modules)
(add-to-list 'erc-notify-list "toonn")
;; (setq erc-notify-list nil)

(defun zp/erc-connect ()
  (interactive)
  (erc :server "176.188.242.162" :port 15873 :nick "zaeph" :password (concat "zaeph/freenode:" (zp/get-string-from-file "/home/zaeph/org/pp/irc/freenode/pp.gpg")))
  ;; (erc :server "irc.freenode.net" :port 6667 :nick "zaeph" :password (zp/get-string-from-file "/home/zaeph/org/pp/irc/freenode/pp.gpg"))
  ;; (erc-tls :server "irc.myanonamouse.net" :port 6697 :nick "zaeph" :password (zp/get-string-from-file "/home/zaeph/org/pp/irc/mam/pp.gpg"))
  )

;; ========================================
;; ================ CIRCE =================
;; ========================================

(require 'circe)

(enable-circe-color-nicks)
(enable-lui-track-bar)

(setq circe-format-say "{nick:15s} {body}")
(setq circe-format-server-message "               *** {body}")
(setq circe-format-self-say "{nick:15s} {body}")
;; (setq circe-format-say "<{nick}> {body}")

(setq
 lui-time-stamp-position 'right-margin
 lui-fill-type nil)

(defun my-lui-setup ()
  (setq
   fringes-outside-margins t
   right-margin-width 5
   word-wrap t
   wrap-prefix "                "))
(add-hook 'lui-mode-hook 'my-lui-setup)

(add-hook 'lui-mode-hook 'olivetti-mode)

(defface circe-prompt-server-face nil
  "Face used for displaying the name of the server in circe.")
(set-face-attribute 'circe-prompt-server-face nil
		    :foreground "purple"
		    :weight 'normal)
(set-face-attribute 'circe-prompt-face nil
		    :foreground "black"
		    :background "LightSeaGreen")

(defun my-circe-prompt ()
  (lui-set-prompt
   (concat
    "\n"
    (format "%15s"
	    (concat
	     (propertize
	      (concat (buffer-name) " ")
	      'face 'circe-prompt-server-face)
	     (concat
	      (propertize
	       ">"
	       'face 'circe-prompt-face))))
    " ")))
(add-hook 'circe-chat-mode-hook 'my-circe-prompt)


(setq circe-reduce-lurker-spam t)
(setq circe-use-cycle-completion t)

;; (circe-set-display-handler "JOIN" (lambda (&rest ignored) nil))

;; From vifon
(define-key lui-mode-map (kbd "C-c C-o")
  (lambda ()
    (interactive)
    (ffap-next-url t)))

(setq lui-formatting-list '(("\\[[[:digit:]][[:digit:]]\\:[[:digit:]][[:digit:]]\\]" 0 font-lock-comment-face)))

(defun zp/circe-get-pp (server)
  (concat "freenode:" (zp/get-string-from-file "/home/zaeph/org/pp/irc/freenode/pp.gpg")))

(setq circe-network-options
      '(
	;; ("ZNC SSL"
	;;  :host "zaeph.tk"
	;;  ;; :host "176.188.242.162"
	;;  :port "15873"
	;;  :tls t
	;;  :server-buffer-name "{host} ⇄ ZNC"
        ;;  ;; :nick "zaeph"
	;;  ;; :nickserv-password zp/circe-get-pp
	;;  :sasl-username "zaeph"
	;;  :sasl-password zp/circe-get-pp
	;;  :user "zaeph/freenode"
	;;  :pass zp/circe-get-pp
        ;;  :channels ("#ranger" "#emacs")
        ;;  )
	("Weechat Relay"
	 :host "zaeph.tk"
	 ;; :host "176.188.242.162"
	 :port "15873"
	 :tls t
	 :server-buffer-name "{host} ⇄ Weechat"
         :nick "zaeph"
	 ;; :nickserv-password zp/circe-get-pp
	 ;; :user "zaeph"
	 :pass zp/circe-get-pp
         :channels ("#ranger")
         )
	("Freenode Rescue"
         :nick "zaeph_"
	 :host "chat.freenode.net"
	 :port 6667
	 :nickserv-password zp/circe-get-pp
         :channels ("#ranger")
         )))

(defun zp/switch-to-circe-ranger ()
  (interactive)
  (if (string-match "#ranger" (buffer-name))
      (mode-line-other-buffer)
    (switch-to-buffer "#ranger")))

(global-set-key (kbd "H-p") 'zp/switch-to-circe-ranger)

;; circe-notifications
(autoload 'enable-circe-notifications "circe-notifications" nil t)
(eval-after-load "circe-notifications"
  '(setq circe-notifications-watch-strings
      '("vifon")))

(add-hook 'circe-server-connected-hook 'enable-circe-notifications)

;; ========================================
;; ================= MU4E =================
;; ========================================

;; (add-to-list 'load-path "/usr/share/emacs/site-lisp/mu4e")
(add-to-list 'load-path "/home/zaeph/.emacs.d/pkg/mu/mu4e")
(require 'mu4e)
(require 'mu4e-alert)
(require 'org-mu4e)
(setq org-mu4e-link-query-in-headers-mode nil)

;; -----------------------------------------------------------------------------
;; To investigate
(defun remove-nth-element (nth list)
  (if (zerop nth) (cdr list)
    (let ((last (nthcdr (1- nth) list)))
      (setcdr last (cddr last))
      list)))
(setq mu4e-marks (remove-nth-element 5 mu4e-marks))
(add-to-list 'mu4e-marks
     '(trash
       :char ("d" . "▼")
       :prompt "dtrash"
       :dyn-target (lambda (target msg) (mu4e-get-trash-folder msg))
       :action (lambda (docid msg target)
                 (mu4e~proc-move docid
				 (mu4e~mark-check-target target) "+S-u-N"))))

(setq mu4e-alert-interesting-mail-query
      (concat
       "flag:unread maildir:/private/inbox"
       ;; "maildir:/private/inbox"
       " OR "
       "flag:unread maildir:/work/inbox"
       ;; "maildir:/work/inbox"
       ))

(setq mu4e-bookmarks
  `(,(make-mu4e-bookmark
      :name  "Inbox"
      :query "maildir:/private/inbox OR maildir:/work/inbox"
      :key ?i)
    ,(make-mu4e-bookmark
      :name  "Inbox (excluding read)"
      :query "flag:unread AND (maildir:/private/inbox OR maildir:/work/inbox)"
      :key ?I)
    ,(make-mu4e-bookmark
      :name  "Sent"
      :query "maildir:/private/sent OR maildir:/work/sent"
      :key ?s)
    ,(make-mu4e-bookmark
      :name  "Drafts"
      :query "maildir:/private/drafts OR maildir:/work/drafts"
      :key ?d)
    ,(make-mu4e-bookmark
      :name  "Archive (last week)"
      :query "date:1w.. AND (maildir:/private/archive OR maildir:/work/archive)"
      :key ?a)
    ,(make-mu4e-bookmark
      :name  "Unread messages"
      :query "flag:unread AND NOT (maildir:/private/trash OR maildir:/work/trash)"
      :key ?u)
    ,(make-mu4e-bookmark
      :name "Today's messages"
      :query "date:today..now"
      :key ?t)
    ,(make-mu4e-bookmark
      :name "Last 7 days"
      :query "date:7d..now"
      :key ?w)
    ,(make-mu4e-bookmark
      :name "Messages with images"
      :query "mime:image/*"
      :key ?p)))

(define-key mu4e-main-mode-map (kbd "c") 'mu4e-compose-new)
(define-key mu4e-headers-mode-map (kbd "c") 'mu4e-compose-new)


;; show images
;; (setq mu4e-view-show-images t
;;       mu4e-view-image-max-width 800)

;; use imagemagick, if available
;; (when (fboundp 'imagemagick-register-types)
;;   (imagemagick-register-types))

;; IMAP takes care of deletion
(setq mu4e-sent-messages-behavior 'delete)

;; ;; Add a column to display what email account the email belongs to.
;; (add-to-list 'mu4e-header-info-custom
;; 	     '(:account
;; 	       :name "Account"
;; 	       :shortname "Account"
;; 	       :help "Which account this email belongs to"
;; 	       :function
;; 	       (lambda (msg)
;; 		 (let ((maildir (mu4e-message-field msg :maildir)))
;; 		   (format "%s" (substring maildir 1 (string-match-p "/" maildir 1)))))))

;; -----------------------------------------------------------------------------



(defun zp/mu4e-alert-grouped-mail-notification-formatter (mail-group all-mails)
  "Default function to format MAIL-GROUP for notification.

ALL-MAILS are the all the unread emails"
  (let* ((mail-count (length mail-group))
         (total-mails (length all-mails))
         (first-mail (car mail-group))
	 ;; Other possible icon:✉
         ;; (title-prefix (format "<span foreground='#75d075'><span font_desc='Noto Color Emoji'>💬</span> [%d/%d] New mail%s</span>"
         (title-prefix (format "[%d/%d] <span foreground='#F04949'>New mail%s</span>"
                               mail-count
                               total-mails
                               (if (> mail-count 1) "s" "")))
         (field-value (mu4e-alert--get-group first-mail))
         (title-suffix (format (pcase mu4e-alert-group-by
                                 (`:from "from %s:")
                                 (`:to "to %s:")
                                 (`:maildir "in %s:")
                                 (`:priority "with %s priority:")
                                 (`:flags "with %s flags:"))
                               field-value))
         (title (format "%s %s" title-prefix title-suffix)))
    (list :title title
          :body (concat "• "
                        (s-join "\n• "
                                (mapcar (lambda (mail)
                                          (replace-regexp-in-string "&" "&amp;" (plist-get mail :subject)))
                                        mail-group))))))

;; Redefine default notify function to include icon
(defun mu4e-alert-notify-unread-messages (mails)
  "Display desktop notification for given MAILS."
  (let* ((mail-groups (funcall mu4e-alert-mail-grouper
                               mails))
         (sorted-mail-groups (sort mail-groups
                                   mu4e-alert-grouped-mail-sorter))
         (notifications (mapcar (lambda (group)
                                  (funcall mu4e-alert-grouped-mail-notification-formatter
                                           group
                                           mails))
                                sorted-mail-groups)))
    (dolist (notification (cl-subseq notifications 0 (min 5 (length notifications))))
      (alert (plist-get notification :body)
             :title (plist-get notification :title)
             :category "mu4e-alert"
	     :icon "gmail-2"))
    (when notifications
      (mu4e-alert-set-window-urgency-maybe))))

(setq mu4e-alert-set-window-urgency nil
      mu4e-alert-email-notification-types '(subjects)
      mu4e-alert-grouped-mail-notification-formatter 'zp/mu4e-alert-grouped-mail-notification-formatter
      mu4e-headers-show-threads t)



(defun zp/mu4e-alert-refresh ()
  (interactive)
  (mu4e-alert-enable-mode-line-display)
  (mu4e-alert-enable-notifications))

(defun zp/mu4e-update-index-and-refresh ()
  (interactive)
  (mu4e-update-index)
  (mu4e~request-contacts)
  ;; (mu4e~headers-maybe-auto-update)
  (zp/mu4e-alert-refresh))

(mu4e-alert-set-default-style 'libnotify)
(add-hook 'mu4e-main-mode-hook 'delete-other-windows)

(add-hook 'after-init-hook #'mu4e-alert-enable-notifications)
(add-hook 'after-init-hook #'mu4e-alert-enable-mode-line-display)
(add-hook 'mu4e-index-updated-hook 'mu4e~headers-maybe-auto-update)
(add-hook 'mu4e-index-updated-hook 'zp/mu4e-alert-refresh)

(defun mu4e-headers-config ()
  "Modify keymaps used by `mu4e-mode'."
  (local-set-key (kbd "C-/") 'mu4e-headers-query-prev)
  (local-set-key (kbd "\\")  'mu4e-headers-query-prev)
  (local-set-key (kbd "C-?") 'mu4e-headers-query-next)
  (local-set-key (kbd "|")   'mu4e-headers-query-next)
  )
(setq mu4e-headers-mode-hook 'mu4e-headers-config)

(setq mu4e-maildir (expand-file-name "/home/zaeph/mail")
      mu4e-change-filenames-when-moving   t
      mu4e-get-mail-command "check-mail active"
      mu4e-hide-index-messages t
      mu4e-update-interval nil
      mu4e-headers-date-format "%Y-%m-%d %H:%M"
      )

(defun zp/rewrite-function (contact)
  (let ((name (or (plist-get contact :name) ""))
         (mail (plist-get contact :mail)))
    (cond
      ;; jonh smiht --> John Smith
      ;; ((string= "jonh smiht" name)
      ;;   (plist-put contact :name "John C. Smith")
      ;;   contact)
      ;; remove evilspammer from the contacts list
      ((string= "nic022@hotnail.fr" mail) nil)
      ;; others stay as the are
      (t contact))))

(setq mu4e-contact-rewrite-function 'zp/rewrite-function)

(setq mu4e-headers-fields
      '( (:date          .  25)    ;; alternatively, use :human-date
	 (:flags         .   6)
	 (:from          .  22)
	 (:subject       .  nil)))

(setq mu4e-compose-format-flowed t)

;; This allows me to use 'helm' to select mailboxes
(setq mu4e-completing-read-function 'completing-read)
;; Why would I want to leave my message open after I've sent it?
(setq message-kill-buffer-on-exit t)
;; Don't ask for a 'context' upon opening mu4e
(setq mu4e-context-policy 'pick-first)
;; Don't ask to quit... why is this the default?
(setq mu4e-confirm-quit nil)

(add-to-list 'mu4e-view-actions
  '("ViewInBrowser" . mu4e-action-view-in-browser) t)

(setq mu4e-contexts
      `( ,(make-mu4e-context
	   :name "Private"
	   :match-func (lambda (msg) (when msg
				       (string-prefix-p "/private" (mu4e-message-field msg :maildir))))
	   :vars `(
		   (user-mail-address . ,(zp/get-string-from-file "/home/zaeph/org/pp/private/email"))
		   (user-full-name . "Zaeph")
		   (message-signature-file . "/home/zaeph/org/sig/private")

		   (mu4e-trash-folder  . "/private/trash")
		   (mu4e-refile-folder . "/private/archive")
		   (mu4e-sent-folder   . "/private/sent")
		   (mu4e-drafts-folder . "/private/drafts")

		   (mu4e-maildir-shortcuts . (("/private/inbox"   . ?i)
					      ("/private/sent"    . ?s)
					      ("/private/trash"   . ?t)
					      ("/private/archive" . ?a)))
		   ))
	 ,(make-mu4e-context
	   :name "Work"
	   :match-func (lambda (msg) (when msg
				       (string-prefix-p "/work" (mu4e-message-field msg :maildir))))
	   :vars `(
		   (user-mail-address . ,(zp/get-string-from-file "/home/zaeph/org/pp/work/email"))
		   (user-full-name . "Leo Vivier")
		   (message-signature-file . "/home/zaeph/org/sig/work")

		   (mu4e-trash-folder  . "/work/trash")
		   (mu4e-refile-folder . "/work/archive")
		   (mu4e-sent-folder   . "/work/sent")
		   (mu4e-drafts-folder . "/work/drafts")

		   (mu4e-maildir-shortcuts . (("/work/inbox"   . ?i)
					      ("/work/sent"    . ?s)
					      ("/work/trash"   . ?t)
					      ("/work/archive" . ?a)))
		   ))
	 ))

;; Editing modeline display to add a space after the `]'
(defun mu4e-context-label ()
  "Propertized string with the current context name, or \"\" if
  there is none."
  (if (mu4e-context-current)
    (concat "[" (propertize (mu4e~quote-for-modeline
			      (mu4e-context-name (mu4e-context-current)))
		  'face 'mu4e-context-face) "] ") ""))

(setq message-send-mail-function 'smtpmail-send-it
      smtpmail-auth-credentials
      (expand-file-name "/home/zaeph/.authinfo.gpg")
      )

(setq send-mail-function 'sendmail-send-it)
(setq message-send-mail-function 'message-send-mail-with-sendmail)

(require 'footnote)

;; Format footnotes for message-mode
;; Default value had a space at the end causing it to be reflowed.
(setq footnote-section-tag "Footnotes:")

(require 'epg-config)
(setq mml2015-use 'epg
      epg-user-id (zp/get-string-from-file "/home/zaeph/org/pp/gpg/gpg-key-id")
      mml-secure-openpgp-sign-with-sender t
      mml-secure-openpgp-encrypt-to-self t)

(add-hook 'message-mode-hook #'flyspell-mode)
(add-hook 'message-mode-hook #'electric-quote-local-mode)
(add-hook 'message-mode-hook #'footnote-mode)
(add-hook 'message-mode-hook (lambda ()
				(zp/helm-ispell-preselect "French")))

(setq electric-quote-context-sensitive 1)
;; -----------------------------------------------------------------------------
;; Experimental patch for electric-quote
;; Not necessary since 26.1, since this function has been modified to accommodate ‘electric-quote-chars’
;; (defun electric-quote-post-self-insert-function ()
;;   "Function that `electric-quote-mode' adds to `post-self-insert-hook'.
;; This requotes when a quoting key is typed."
;;   (when (and electric-quote-mode
;;              (memq last-command-event '(?\' ?\`)))
;;     (let ((start
;;            (if (and comment-start comment-use-syntax)
;;                (when (or electric-quote-comment electric-quote-string)
;;                  (let* ((syntax (syntax-ppss))
;;                         (beg (nth 8 syntax)))
;;                    (and beg
;;                         (or (and electric-quote-comment (nth 4 syntax))
;;                             (and electric-quote-string (nth 3 syntax)))
;;                         ;; Do not requote a quote that starts or ends
;;                         ;; a comment or string.
;;                         (eq beg (nth 8 (save-excursion
;;                                          (syntax-ppss (1- (point)))))))))
;;              (and electric-quote-paragraph
;;                   (derived-mode-p 'text-mode)
;;                   (or (eq last-command-event ?\`)
;;                       (save-excursion (backward-paragraph) (point)))))))
;;       (when start
;;         (save-excursion
;;           (if (eq last-command-event ?\`)
;;               (cond ((search-backward "“`" (- (point) 2) t)
;;                      (replace-match "`")
;;                      (when (and electric-pair-mode
;;                                 (eq (cdr-safe
;;                                      (assq ?‘ electric-pair-text-pairs))
;;                                     (char-after)))
;;                        (delete-char 1))
;;                      (setq last-command-event ?“))
;; 		    ((search-backward "‘`" (- (point) 2) t)
;;                      (replace-match "“")
;;                      (when (and electric-pair-mode
;;                                 (eq (cdr-safe
;;                                      (assq ?‘ electric-pair-text-pairs))
;;                                     (char-after)))
;;                        (delete-char 1))
;;                      (setq last-command-event ?“))
;;                     ((search-backward "`" (1- (point)) t)
;;                      (replace-match "‘")
;;                      (setq last-command-event ?‘)))
;;             (cond ((search-backward "”'" (- (point) 2) t)
;;                    (replace-match "'")
;;                    (setq last-command-event ?”))
;; 		  ((search-backward "’'" (- (point) 2) t)
;;                    (replace-match "”")
;;                    (setq last-command-event ?”))
;;                   ((search-backward "'" (1- (point)) t)
;;                    (replace-match "’")
;;                    (setq last-command-event ?’)))))))))
;; -----------------------------------------------------------------------------



;; SMTP
;; I have my "default" parameters from Gmail
;; (setq mu4e-sent-folder "/home/zaeph/mail/sent"
;;       ;; mu4e-sent-messages-behavior 'delete ;; Unsure how this should be configured
;;       mu4e-drafts-folder "/home/zaeph/mail/drafts"
;;       user-mail-address "[DATA EXPUNGED]"
;;       smtpmail-default-smtp-server "smtp.gmail.com"
;;       smtpmail-smtp-server "smtp.gmail.com"
;;       smtpmail-smtp-service 587)

;; Now I set a list of 
;; (defvar my-mu4e-account-alist
;;   '(("personal"
;;      (mu4e-sent-folder "/personal/sent")
;;      (user-mail-address "[DATA EXPUNGED]")
;;      (smtpmail-smtp-user "[DATA EXPUNGED]")
;;      (smtpmail-local-domain "gmail.com")
;;      (smtpmail-default-smtp-server "smtp.gmail.com")
;;      (smtpmail-smtp-server "smtp.gmail.com")
;;      (smtpmail-smtp-service 587)
;;      )
;;     ("work"
;;      (mu4e-sent-folder "/work/sent")
;;      (user-mail-address "[DATA EXPUNGED]")
;;      (smtpmail-smtp-user "[DATA EXPUNGED]")
;;      (smtpmail-local-domain "gmail.com")
;;      (smtpmail-default-smtp-server "smtp.gmail.com")
;;      (smtpmail-smtp-server "smtp.gmail.com")
;;      (smtpmail-smtp-service 587)
;;      )
;;     ))

;; (defun my-mu4e-set-account ()
;;   "Set the account for composing a message."
;;   (let* ((account
;;           (if mu4e-compose-parent-message
;;               (let ((maildir (mu4e-message-field mu4e-compose-parent-message :maildir)))
;;                 (string-match "/\\(.*?\\)/" maildir)
;;                 (match-string 1 maildir))
;;             (completing-read (format "Compose with account: (%s) "
;;                                      (mapconcat #'(lambda (var) (car var))
;;                                                 my-mu4e-account-alist "/"))
;;                              (mapcar #'(lambda (var) (car var)) my-mu4e-account-alist)
;;                              nil t nil nil (caar my-mu4e-account-alist))))
;;          (account-vars (cdr (assoc account my-mu4e-account-alist))))
;;     (if account-vars
;;         (mapc #'(lambda (var)
;;                   (set (car var) (cadr var)))
;;               account-vars)
;;       (error "No email account found"))))
;; (add-hook 'mu4e-compose-pre-hook 'my-mu4e-set-account)



;; ========================================
;; ============== MODE-LINE ===============
;; ========================================

;; Spaceline
(require 'spaceline-config)



;; ========================================
;; ================ MODES =================
;; ========================================

;; Modes
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode 0)
(fringe-mode 15)
(show-paren-mode 1)
(yas-global-mode 1)
(column-number-mode 1)
(blink-cursor-mode -1)
(winner-mode 1)
(set-default 'truncate-lines t)
(electric-quote-mode 1)
;; (global-visible-mark-mode 1)

(setq next-line-add-newlines nil)
(setq-default require-final-newline nil)
(setq scroll-preserve-screen-position 't)


;; (global-linum-mode 1)
;; (global-hl-line-mode 1)

;; Windmove
(windmove-default-keybindings 'super)
(setq windmove-wrap-around t)
;; (desktop-save-mode 1)

;; Focus follows mouse
;; (setq focus-follows-mouse t)
;; (setq mouse-autoselect-window t)
(setq focus-follows-mouse nil)
(setq mouse-autoselect-window nil)

;; Linum parameters
(require 'linum)
(setq linum-format " %d ")		;Add spaces before and after

;; Mouse & Scrolling options
(setq mouse-wheel-flip-direction 1
      mouse-wheel-scroll-amount '(2 ((shift) . 1) ((control)))
      mouse-wheel-progressive-speed nil
      mouse-wheel-follow-mouse 't
      auto-hscroll-mode 'current-line)

;; Disable side movements
;; (global-set-key (kbd "<mouse-6>") 'ignore)
;; (global-set-key (kbd "<mouse-7>") 'ignore)
;; (global-set-key (kbd "<triple-mouse-7>") 'ignore)
;; (global-set-key (kbd "<triple-mouse-6>") 'ignore)

;; Bell
(setq visible-bell 1)

;; Fullscreen
(toggle-frame-maximized)

;; Time
(setq display-time-default-load-average nil)
(display-time-mode 1)

;; DocView
;; (add-hook 'doc-view-mode-hook 'auto-revert-mode)

(defun zp/toggle-pdf-view-auto-slice-minor-mode ()
  (interactive)
  (call-interactively 'pdf-view-auto-slice-minor-mode)
  (if (not pdf-view-auto-slice-minor-mode)
      (progn
	(pdf-view-reset-slice))))

;; pdf-tools
(pdf-tools-install)
(define-key pdf-view-mode-map (kbd "m") 'pdf-view-midnight-minor-mode)
(define-key pdf-view-mode-map (kbd "S") 'zp/toggle-pdf-view-auto-slice-minor-mode)
(define-key pdf-view-mode-map (kbd "c") 'zp/pdf-view-continuous-toggle)
(add-hook #'pdf-view-mode-hook #'pdf-view-midnight-minor-mode)
(add-hook #'pdf-view-mode-hook #'pdf-view-auto-slice-minor-mode)

(setq pdf-view-continuous t)

(defun zp/pdf-view-continuous-toggle ()
  (interactive)
  (cond ((eq pdf-view-continuous nil)
	 (setq pdf-view-continuous t)
	 (message "Page scrolling: Continous"))
	(t
	 (setq pdf-view-continuous nil)
	 (message "Page scrolling: Constrained"))))

;; Sublimity
;; (sublimity-mode 0)
;; (require 'sublimity-scroll)


;; Suppress bells for reaching beginning and end of buffer
(defun my-command-error-function (data context caller)
  "Ignore the buffer-read-only, beginning-of-buffer,
end-of-buffer signals; pass the rest to the default handler."
  (when (not (memq (car data) '(buffer-read-only
                                beginning-of-buffer
                                end-of-buffer)))
    (command-error-default-function data context caller)))

(setq command-error-function #'my-command-error-function)


;; Only hl-line from end of line

;; (defun my-hl-line-range-function ()
;;   (cons (line-end-position) (line-beginning-position 2)))
;; (setq hl-line-range-function #'my-hl-line-range-function)

;; (when window-system
;;   (require 'hl-line)
;;   (set-face-attribute 'hl-line nil :inherit nil :background "#111111")
;;   (setq global-hl-line-sticky-flag t)
;;   (global-hl-line-mode 1))

;; Way to enable minor modes based on filenames
;; Added with the package `auto-minor-mode-alist'
;; ...but can also add them with file-variables
(add-to-list 'auto-minor-mode-alist '("\\journal.*\\'" . visual-line-mode))
(add-to-list 'auto-minor-mode-alist '("\\journal.*\\'" . olivetti-mode))
(add-to-list 'auto-minor-mode-alist '("\\journal.*\\'" . flyspell-mode))

(add-to-list 'auto-minor-mode-alist '("edit-in-emacs.txt" . visual-line-mode))
(add-to-list 'auto-minor-mode-alist '("edit-in-emacs.txt" . olivetti-mode))
(add-to-list 'auto-minor-mode-alist '("edit-in-emacs.txt" . flyspell-mode))
(add-to-list 'auto-minor-mode-alist '("edit-in-emacs.txt" . save-silently-mode))

;; (add-to-list 'auto-minor-mode-alist '("edit-in-emacs.html" . visual-line-mode))
;; (add-to-list 'auto-minor-mode-alist '("edit-in-emacs.html" . olivetti-mode))
;; (add-to-list 'auto-minor-mode-alist '("edit-in-emacs.html" . flyspell-mode))
(add-to-list 'auto-minor-mode-alist '("edit-in-emacs.html" . save-silently-mode))
;; (setq auto-minor-mode-alist nil)

(defun zp/kanji-add-furigana ()
  "Adds furigana to the kanji at point.
If text is selected, adds furigana to the selected kanji instead."
  (interactive)
  (if (not (region-active-p))
      (progn
	(call-interactively 'set-mark-command)
	(call-interactively 'forward-char)))
  (yas-expand-snippet (yas-lookup-snippet "anki-ruby")))

(defun zp/save-buffers-kill-terminal-silently ()
  (interactive)
  (save-buffers-kill-terminal t))

(define-minor-mode save-silently-mode
  "Save buffers silently when exiting."
  :lighter " SS"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-x C-c") 'zp/save-buffers-kill-terminal-silently)
            (define-key map (kbd "C-c C-k") 'zp/kanji-add-furigana)
            (define-key map (kbd "M-n") 'zp/kanji-add-furigana)
            map))

;; Recentf
(setq recentf-max-menu-items 100)

;; Anzu
;; Display search information in mode-line
(global-anzu-mode +1)
(setq anzu-cons-mode-line-p nil)

;; Tramp
(setq tramp-default-method "ssh")



;; ========================================
;; ============= INPUT METHODS ============
;; ========================================

(setq lang 'en)

;; Old input method

;; ;; Korean
;; (global-set-key (kbd "C-S-k")
;; 		(lambda ()
;; 		  (interactive)
;; 		  (if (not (eq lang 'ko))
;; 		      (progn
;; 			(set-input-method 'korean-hangul)
;; 			(setq lang 'ko))
;; 		    (progn
;; 		      (set-input-method 'nil)
;; 		      (setq lang 'en)))))
;; ;; Latin
;; (global-set-key (kbd "C-S-l")
;; 		(lambda ()
;; 		  (interactive)
;; 		  (if (not (eq lang 'fr))
;; 		      (progn
;; 			(set-input-method 'latin-1-prefix)
;; 			(setq lang 'fr))
;; 		    (progn
;; 		      (set-input-method 'nil)
;; 		      (setq lang 'en)))))
;; ;; IPA
;; (global-set-key (kbd "C-M-;")
;; 		(lambda ()
;; 		  (interactive)
;; 		  (if (not (eq lang 'ipa))
;; 		      (progn
;; 			(set-input-method 'ipa-x-sampa)
;; 			(setq lang 'ipa))
;; 		    (progn
;; 		      (set-input-method 'nil)
;; 		      (setq lang 'en)))))



;; ========================================
;; ================ BACKUP ================
;; ========================================

(setq backup-directory-alist `(("." . "/home/zaeph/.saves")))
(setq backup-by-copying t)
(setq delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)


;; ========================================
;; ================ DIARY =================
;; ========================================

(setq diary-file "/home/zaeph/diary")



;; ========================================
;; =============== AUCTeX =================
;; ========================================

;; Set default library
(setq-default TeX-engine 'xetex
	      TeX-save-query nil
	      TeX-parse-self t
	      TeX-auto-save t
	      LaTeX-includegraphics-read-file 'LaTeX-includegraphics-read-file-relative)
(setq reftex-default-bibliography '("/home/zaeph/org/bib/monty-python.bib"))
;; (setq reftex-default-bibliography nil)
(setq warning-suppress-types nil)
(add-to-list 'warning-suppress-types '(yasnippet backquote-change))

;; Used to prevent radio tables from having trailing $
(setq LaTeX-verbatim-environments '("verbatim" "verbatim*" "comment"))

(setq LaTeX-csquotes-close-quote "}"
      LaTeX-csquotes-open-quote "\\enquote{")
(setq TeX-open-quote "\\enquote{"
      TeX-close-quote "}")

(setq font-latex-fontify-script nil)
(setq font-latex-fontify-sectioning 'color)

(set-default 'preview-scale-function 3)

(defun zp/LaTeX-remove-macro ()
  "Remove current macro and return `t'.  If no macro at point,
return `nil'."
  (interactive)
  (when (TeX-current-macro)
    (let ((bounds (TeX-find-macro-boundaries))
          (brace  (save-excursion
                    (goto-char (1- (TeX-find-macro-end)))
                    (TeX-find-opening-brace))))
      (delete-region (1- (cdr bounds)) (cdr bounds))
      (delete-region (car bounds) (1+ brace)))
    t))

;; Hook
(defun zp/LaTeX-mode-config ()
  "Modify keymaps used by `latex-mode'."
  (local-set-key (kbd "C-c DEL") 'zp/LaTeX-remove-macro)
  (local-set-key (kbd "C-c <C-backspace>") 'zp/LaTeX-remove-macro)
  (local-set-key (kbd "C-c C-t C-v") 'zp/tex-view-program-switch))
(setq LaTeX-mode-hook '(zp/LaTeX-mode-config))



;; ========================================
;; =============== ORG-MODE ===============
;; ========================================

(require 'org-habit)
(add-to-list 'org-modules 'org-habit)
;; (setq org-habit-show-habits-only-for-today nil)

;; Experimental way to handle narrowing from org-agenda for my journal
;; Couldn't figure out how to limit it to a particular custom-agenda
;; (advice-add 'org-agenda-goto :after
;;             (lambda (&rest args)
;;               (org-narrow-to-subtree)))
;; (advice-add 'org-agenda-switch-to :after
;;             (lambda (&rest args)
;;               (org-narrow-to-subtree)))

;; Possibe solution to async export
;; (setq org-export-async-init-file "/home/zaeph/.emacs.d/async-init.el")

;;; Hook for org-clock-in
;;; Deprecated because I don't really need it
;; (defun zp/org-todo-started ()
;;   "Mark entry as started.
;; Used as a hook to `org-clock-in-hook'."
;;   (org-todo "STRT"))

;; (add-hook 'org-clock-in-hook 'zp/org-todo-started)

;; Options
(setq org-clock-into-drawer "LOGBOOK-CLOCK"
      org-log-into-drawer "LOGBOOK-NOTES"
      org-log-state-notes-insert-after-drawers nil
      ;; org-log-into-drawer nil
      ;; org-log-state-notes-insert-after-drawers t
      org-log-done 'time
      org-enforce-todo-dependencies t	;Careful with this one, easy to fuck up
      ;; org-enforce-todo-dependencies nil
      org-adapt-indentation nil
      org-clock-sound t
      org-export-in-background t
      org-image-actual-width nil 	;Ensures that images displayed within emacs can be resized with #+ATTR_ORG:
      org-hide-emphasis-markers nil	;Fontification
      org-ellipsis "…"
      org-track-ordered-property-with-tag "ORDERED"
      ;; org-tags-exclude-from-inheritance '("project")
      org-tags-exclude-from-inheritance nil
      org-agenda-hide-tags-regexp "recurring\\|waiting\\|standby"
      org-catch-invisible-edits 'show
      org-footnote-define-inline 1
      )

;; Add curly quotes to list of pre- and post-matches for emphasis markers
(setq org-emphasis-regexp-components '("- 	('‘\"“’{" "- 	.,:!?;'’\"”)}\\[" " 	
" "." 1))

;; (eval-after-load 'org '(require 'org-pdfview))

(add-to-list 'org-file-apps
             '("\\.pdf\\'" . (lambda (file link)
			       (org-pdfview-open link))))

;; (setq org-file-apps '(("\\.pdf\\'" lambda
;; 		       (file link)
;; 		       (org-pdfview-open link))
;; 		      (auto-mode . emacs)
;; 		      ("\\.mm\\'" . default)
;; 		      ("\\.x?html?\\'" . default)
;; 		      ("\\.pdf\\'" . default)))

;; -----------------------------------------------------------------------------
;; Template for new emphasis / fontify
;; Do not modify org-emphasis-alist, it's only for modifying the default ones
;; Also, has a little bug where it colours the rest of the line white
;; (defun org-add-my-extra-fonts ()
;;   "Add alert and overdue fonts."
;;   (add-to-list 'org-font-lock-extra-keywords '("\\(!\\)\\([^\n\r\t]+?\\)\\(!\\)" (1 '(face org-habit-overdue-face invisible t)) (2 'org-todo) (3 '(face org-habit-overdue-face invisible t)))))
;;   (add-to-list 'org-font-lock-extra-keywords '("\\(%\\)\\([^\n\r\t]+?\\)\\(%\\)" (1 '(face org-habit-overdue-face invisible t)) (2 'org-done) (3 '(face org-habit-overdue-face invisible t)))))

;; (add-hook 'org-font-lock-set-keywords-hook #'org-add-my-extra-fonts)
;; -----------------------------------------------------------------------------

(setq org-todo-keywords '(
	;; Default
	(sequence "TODO(t)" "NEXT(n)" "STRT(S)" "|" "DONE(d)")
	;; Action
	;; (sequence "SCHD(m!)" "PREP(!)" "READ(r!)" "DBRF(D!)" "REVW(R!)" "|" "DONE(d!)")
	;; Extra
	;; (sequence "STBY(s)" "WAIT(w@/!)" "|" "CXLD(x@/!)")
	(sequence "STBY(s)" "|" "CXLD(x@/!)")
	(sequence "WAIT(w!)" "|" "CXLD(x@/!)")
	))
(setq org-todo-keyword-faces '(
			       ("TODO" :inherit org-todo-todo)
			       ("NEXT" :inherit org-todo-next)
			       ("STRT" :inherit org-todo-strt)
			       ("DONE" :inherit org-todo-done)

			       ("STBY" :inherit org-todo-stby)
			       ("WAIT" :inherit org-todo-wait)
			       ("CXLD" :inherit org-todo-cxld)))

			       ;; ("SCHD" :inherit org-todo-box :background "DeepPink1")
			       ;; ("PREP" :inherit org-todo-box :background "DeepPink1")
			       ;; ("READ" :inherit org-todo-box :background "SkyBlue4")
			       ;; ("DBRF" :inherit org-todo-box :background "gold3")
			       ;; ("REVW" :inherit org-todo-box :background "gold3")

(setq org-highest-priority 65
      org-lowest-priority 69
      org-default-priority 68)

;; (setq org-priority-faces '((65 . (:foreground "red1"))
;; 			   (66 . (:foreground "DarkOrange1"))
;; 			   (67 . (:foreground "gold1"))
;; 			   (68 . (:foreground "gray40"))
;; 			   (69 . (:foreground "gray20"))))

;; DEFCON theme
(setq org-priority-faces '((65 . (:inherit org-priority-face-a))
			   (66 . (:inherit org-priority-face-b))
			   (67 . (:inherit org-priority-face-c))
			   (68 . (:inherit org-priority-face-d))
			   (69 . (:inherit org-priority-face-e))))
(setq org-tags-column -77)		;Default: -77
(setq org-agenda-tags-column -90)	;Default: auto OR -80
(setq org-habit-graph-column 50)

(setq org-todo-state-tags-triggers
      '(("CXLD" ("cancelled" . t) ("standby") ("waiting"))
	("STBY" ("standby"   . t) ("cancelled") ("waiting"))
	("WAIT" ("waiting"   . t) ("cancelled") ("standby"))
	("TODO" ("cancelled") ("standby") ("waiting"))
	("NEXT" ("cancelled") ("standby") ("waiting"))
	("STRT" ("cancelled") ("standby") ("waiting"))
	("WAIT" ("cancelled") ("standby") ("waiting"))
	("DONE" ("cancelled") ("standby") ("waiting"))
	(""     ("cancelled") ("standby") ("waiting")))
      ;; Custom colours for specific tags
      ;; Used to cause problem when rescheduling items in the agenda, but it seems to be gone now.
      org-tag-faces
      '(("@home"	. org-tag-location)
      	("@work"	. org-tag-location)
      	("@town"	. org-tag-location)
      	("standby"	. org-tag-todo)
      	("cxld"		. org-tag-todo)
      	("waiting"	. org-tag-todo)
      	("recurring"	. org-tag-todo)
      	("assignment"	. org-tag-important)
      	("exam"		. org-tag-important)
      	("important"	. org-tag-important)
      	("reading"	. org-tag-reading)
      	("french"	. org-tag-french)))



;; (setq org-columns-default-format "%TODO(State) %Effort(Effort){:} %CLOCKSUM %70ITEM(Task)")
(setq org-columns-default-format "%55ITEM(Task) %TODO(State) %Effort(Effort){:} %CLOCKSUM")

;; Global values for properties
(setq org-global-properties (quote (("Effort_ALL" . "0:05 0:10 0:15 0:30 0:45 1:00 1:30 2:00 2:30 3:00 3:30 4:00 4:30 5:00 5:30 6:00 0:00")
                                    ("STYLE_ALL" . "habit")
				    ("APPT_WARNTIME_ALL" . "5 10 15 20 25 30 35 40 45 50 55 60 0")
				    )))

;; (setq org-global-properties nil)


(setq org-archive-location "%s.archive::")
;; (setq org-archive-location "%s.archive.org.gpg::")
;; (setq org-archive-location "archive.org.gpg::")
;; (setq org-archive-location "/home/zaeph/org/archive.org.gpg::* From %s")

;; Babel
(require 'ob-async)
(add-hook 'ob-async-pre-execute-src-block-hook
        '(lambda ()
           (setq org-ditaa-jar-path "/usr/share/java/ditaa/ditaa-0.11.jar")))

;; Deactivated since migrated to Linux
;; (org-babel-do-load-languages 'org-babel-load-languages
;; 			     '((R . t)
;; 			       (latex . t)
;; 			       (ledger . t)))

;; Prototype babel
(org-babel-do-load-languages 'org-babel-load-languages
			     '((shell . t)
			       (ditaa . t)))

(add-hook 'org-babel-after-execute-hook 'org-display-inline-images 'append)

(setq org-ditaa-jar-path "/usr/share/java/ditaa/ditaa-0.11.jar")


(add-to-list 'safe-local-variable-values
	     '(after-save-hook . org-html-export-to-html))
(add-to-list 'safe-local-variable-values
	     '(org-confirm-babel-evaluate . nil))
(add-to-list 'safe-local-variable-values
	     '( . nil))

(defun zp/org-overview (arg)
  (interactive "p")
  (let ((pos-before (point)))
    (setq-local zp/org-narrow-previous-position pos-before))
  (widen)
  (org-overview)
  (if (not (eq arg 4))
      (beginning-of-buffer))
  (recenter-top-bottom)
  (zp/play-sound-turn-page))

;; org-narrow movements

(defun zp/org-narrow-to-subtree ()
  "Move to the next subtree at same level, and narrow the buffer to it."
  (interactive)
  (org-narrow-to-subtree)
  (message "Narrowing to tree at point.")
  (zp/play-sound-turn-page))

(defun zp/org-widen ()
  "Move to the next subtree at same level, and narrow the buffer to it."
  (interactive)
  (let ((pos-before (point)))
    (setq-local zp/org-narrow-previous-position pos-before))
  (widen)
  (message "Removing narrowing.")
  (zp/play-sound-turn-page))

(defun zp/org-narrow-forwards ()
  "Move to the next subtree at same level, and narrow the buffer to it."
  (interactive)
  (widen)
  (org-forward-heading-same-level 1)
  (org-narrow-to-subtree)
  (message "Narrowing to next tree.")
  (zp/play-sound-turn-page))

(defun zp/org-narrow-backwards ()
  "Move to the next subtree at same level, and narrow the buffer to it."
  (interactive)
  (widen)
  (org-backward-heading-same-level 1)
  (org-narrow-to-subtree)
  (message "Narrowing to previous tree.")
  (zp/play-sound-turn-page))

(defun zp/org-narrow-up-heading (arg)
  "Move to the next subtree at same level, and narrow the buffer to it."
  (interactive "p")
  (let ((pos-before (point)))
    (setq-local zp/org-narrow-previous-position pos-before)
    (widen)
    (org-reveal)
    (outline-up-heading 1)
    (org-narrow-to-subtree)
    (if (eq arg 4)
	(progn
	  (goto-char pos-before)
	  (recenter-top-bottom)))
    (message "Narrowing to tree above.")
    (zp/play-sound-turn-page)))

(defun zp/org-narrow-previous-heading (arg)
  "Move to the previously narrowed tree, and narrow the buffer to it."
  (interactive "p")
  (if (bound-and-true-p zp/org-narrow-previous-position)
      (let ((pos-before zp/org-narrow-previous-position))
	(goto-char zp/org-narrow-previous-position)
	(org-reveal)
	(org-cycle)
	(org-narrow-to-subtree)
	(setq zp/org-narrow-previous-position nil)
	(message "Narrowing to previously narrowed tree.")
	(zp/play-sound-turn-page))
    (message "Couldn’t find a previous position.")))

;; Hook
(defun org-mode-config ()
  "Modify keymaps used by `org-mode'."
  (local-set-key (kbd "C-c i") 'org-indent-mode)
  (local-set-key (kbd "C-c [") 'nil)
  (local-set-key (kbd "C-c ]") 'nil)
  (local-set-key (kbd "C-c C-.") 'org-time-stamp)
  (local-set-key (kbd "C-c C-x r") 'zp/org-set-appt-warntime)
  (local-set-key (kbd "C-c C-x l") 'zp/org-set-location)
  (local-set-key (kbd "C-c C-x d") 'org-delete-property)
  (local-set-key (kbd "C-c C-x D") 'org-insert-drawer)
  (local-set-key (kbd "S-<backspace>") 'zp/kill-indirect-buffer)
  (local-set-key (kbd "C-x n o") 'zp/org-overview)
  (local-set-key (kbd "C-x n u") 'zp/org-narrow-up-heading)
  (local-set-key (kbd "C-x n y") 'zp/org-narrow-previous-heading)
  (local-set-key (kbd "C-x n s") 'zp/org-narrow-to-subtree)
  (local-set-key (kbd "C-x n f") 'zp/org-narrow-forwards)
  (local-set-key (kbd "C-x n b") 'zp/org-narrow-backwards)
  (local-set-key (kbd "C-x n w") 'zp/org-widen)
  (local-set-key (kbd "M-p") 'org-metaup)
  (local-set-key (kbd "M-n") 'org-metadown)
  ;; (local-set-key (kbd "C-c C-w") 'org-refile)
  ;; (local-set-key (kbd "C-c C-S-w") 'zp/org-refile-with-paths)
  )
(setq org-mode-hook 'org-mode-config)
(define-key mode-specific-map (kbd "a") 'org-agenda)



;; ========================================
;; =============== SHORTCUTS ==============
;; ========================================

(define-prefix-command 'ledger-map)
(global-set-key (kbd "C-c l") 'ledger-map)
(define-prefix-command 'projects-map)
(global-set-key (kbd "C-c p") 'projects-map)
(define-prefix-command 'classes-map)
(global-set-key (kbd "C-c p c") 'classes-map)
(define-prefix-command 'activism-map)
(global-set-key (kbd "C-c p a") 'activism-map)

(defun zp/set-shortcuts (alist)
  (mapc
   (lambda (x)
     (let ((file-shortcut (car x))
	   (file-path (cdr x)))
       (global-set-key (kbd (concat "C-c " file-shortcut))
		       `(lambda ()
			  (interactive)
			  (find-file ',file-path)))))
   alist))


(setq zp/shortcut-files-alist
      '(("e" . "/home/zaeph/.emacs.d/init.el")
	("I" . "/home/zaeph/org/info.org.gpg"))
      zp/ledger-files-alist
      '(("l l" . "/home/zaeph/org/ledger/main.ledger.gpg")
	("l s" . "/home/zaeph/org/ledger/main-schedule.ledger.gpg")
      	;; ("l f" . "/home/zaeph/org/ledger/french-house.ledger.gpg")
	)
      zp/research-files-alist
      '(("p t" . "/home/zaeph/org/projects/university/research/thesis/thesis.tex")
      	("p T" . "/home/zaeph/org/projects/university/research/presentation/presentation.tex")
      	("p b" . "/home/zaeph/org/bib/monty-python.bib")
      	("p B" . "/home/zaeph/org/projects/university/research/thesis/bibliography/bibliography.tex")
      	;; ("p c" . "/home/zaeph/org/projects/university/research/sty/zaeph.sty")
      	;; ("p C" . "/home/zaeph/org/projects/university/research/sty/presentation.sty")
	)

      zp/org-agenda-files-journals-alist
      '(("j j" . "/home/zaeph/org/journal.org.gpg")
      	("j w" . "/home/zaeph/org/projects/writing/journal.org.gpg")
      	("j u" . "/home/zaeph/org/projects/university/journal.org.gpg")
      	("j r" . "/home/zaeph/org/projects/university/research/journal.org.gpg")
      	("j l" . "/home/zaeph/org/projects/arch-linux/journal.org.gpg")
      	("j s" . "/home/zaeph/org/sports/swimming/journal.org.gpg"))
      zp/org-agenda-files-journals
      (mapcar 'cdr zp/org-agenda-files-journals-alist)

      zp/org-agenda-files-projects-alist
      '(("p w" . "/home/zaeph/org/projects/writing/writing.org.gpg")
      	;; ("p t" . "/home/zaeph/org/projects/tavocat/tavocat.org.gpg")
      	;; ("p k". "/home/zaeph/org/projects/kendeskiñ/kendeskiñ.org.gpg")
      	;; University
      	("p u" . "/home/zaeph/org/projects/university/university.org.gpg")
      	("p r" . "/home/zaeph/org/projects/university/research/research.org.gpg")
	;; ("p c l"	. "/home/zaeph/org/projects/university/classes/university/ling/ling.org.gpg")
	;; ("p c u"	. "/home/zaeph/org/projects/university/classes/university/civ-us/civ-us.org.gpg")
	;; ("p c g"	. "/home/zaeph/org/projects/university/classes/university/civ-gb/civ-gb.org.gpg")
	;; ("p c s"	. "/home/zaeph/org/projects/university/classes/university/space/space.org.gpg")
	;; ("p c i"	. "/home/zaeph/org/projects/university/classes/university/lit/lit.org.gpg")
	;; ("p c s"	. "/home/zaeph/org/projects/university/classes/university/syn/syn.org.gpg")
	;; ("p c t"	. "/home/zaeph/org/projects/university/classes/espe/tronc-commun.org.gpg")
	;; Languages
	("p j" . "/home/zaeph/org/projects/lang/ja/ja.org.gpg")
      	;; Activism
      	;; ("p a d"  . "[DATA EXPUNGED]")
      	;; ("p a s"  . "[DATA EXPUNGED]")
      	;; ("p a c"  . "[DATA EXPUNGED]")
      	;; ("p a m"  . "[DATA EXPUNGED]")
      	)
      zp/org-agenda-files-projects
      (mapcar 'cdr zp/org-agenda-files-projects-alist)

      zp/org-agenda-files-music-alist
      '(("p p" ."/home/zaeph/org/piano.org.gpg"))
      zp/org-agenda-files-music
      (mapcar 'cdr zp/org-agenda-files-music-alist)

      zp/org-agenda-files-sports-alist
      '(
      	("p s" . "/home/zaeph/org/sports/swimming/swimming.org.gpg")
      	;; ("p R" . "/home/zaeph/org/sports/running/running.org.gpg")
      	)
      zp/org-agenda-files-sports
      (mapcar 'cdr zp/org-agenda-files-sports-alist)

      zp/org-agenda-files-tools-alist
      '(("p e" . "/home/zaeph/org/projects/emacs/emacs.org.gpg")
      	("p l" . "/home/zaeph/org/projects/arch-linux/arch-linux.org.gpg"))
      zp/org-agenda-files-tools
      (mapcar 'cdr zp/org-agenda-files-tools-alist)

      zp/org-agenda-files-media-alist
      '(("b" . "/home/zaeph/org/media.org.gpg"))
      zp/org-agenda-files-media
      (mapcar 'cdr zp/org-agenda-files-media-alist)

      zp/org-agenda-files-life-alist
      '(("o" . "/home/zaeph/org/life.org.gpg"))
      zp/org-agenda-files-life
      (mapcar 'cdr zp/org-agenda-files-life-alist))

(defun zp/set-shortcuts-all ()
  (zp/set-shortcuts zp/shortcut-files-alist)
  (zp/set-shortcuts zp/ledger-files-alist)
  (zp/set-shortcuts zp/research-files-alist)
  (zp/set-shortcuts zp/org-agenda-files-journals-alist)
  (zp/set-shortcuts zp/org-agenda-files-projects-alist)
  (zp/set-shortcuts zp/org-agenda-files-music-alist)
  (zp/set-shortcuts zp/org-agenda-files-sports-alist)
  (zp/set-shortcuts zp/org-agenda-files-tools-alist)
  (zp/set-shortcuts zp/org-agenda-files-media-alist)
  (zp/set-shortcuts zp/org-agenda-files-life-alist))

;; (zp/set-shortcuts-all)

;; Helm
(require 'helm)

(define-prefix-command 'zp/helm-map)
(global-set-key (kbd "C-c h") 'zp/helm-map)

(global-set-key (kbd "M-x") 'helm-M-x)
(global-set-key (kbd "<menu>") 'helm-M-x)
(global-set-key (kbd "M-y") 'helm-show-kill-ring)
(global-set-key (kbd "C-x b") 'helm-mini)
(global-set-key (kbd "C-x C-b") 'helm-mini)
(global-set-key (kbd "C-x C-f") 'helm-find-files)
(global-set-key (kbd "M-s M-s") 'helm-occur)
(global-set-key (kbd "C-x r b") 'helm-bookmarks)

(global-set-key (kbd "C-c h o") 'helm-occur)
(global-set-key (kbd "C-c h f") 'helm-find-files)
(global-set-key (kbd "C-c h r") 'helm-regexp)
(global-set-key (kbd "C-c h x") 'helm-register)
(global-set-key (kbd "C-c h b") 'helm-resume)
(global-set-key (kbd "C-c h c") 'helm-colors)
(global-set-key (kbd "C-c h M-:") 'helm-eval-expression-with-eldoc)
(global-set-key (kbd "C-c h i") 'helm-semantic-or-imenu)
(global-set-key (kbd "C-h C-SPC") 'helm-all-mark-rings)
(global-set-key (kbd "C-c h a") 'helm-apropos)
(global-set-key (kbd "C-c h /") 'helm-find)
(global-set-key (kbd "C-c h <tab>") 'helm-lisp-completion-at-point)

(setq helm-M-x-fuzzy-match t
      helm-buffers-fuzzy-matching t
      helm-recentf-fuzzy-match t
      helm-semantic-fuzzy-match t
      helm-imenu-fuzzy-match t
      helm-mode-fuzzy-match t
      helm-completion-in-region-fuzzy-match t
      helm-apropos-fuzzy-match t
      helm-lisp-fuzzy-completion t)

(define-key helm-map (kbd "C-S-o") 'helm-previous-source)


;; Helm Projectile

(global-set-key (kbd "C-c h p") 'helm-projectile)



;; Shortcut for opening Keep (not yet implemented: can't find a good key for it)
;; (global-set-key (kbd "C-<f1>")
;; 		(lambda () (interactive) (org-open-link-from-string "https://keep.google.com/")))



;; ========================================
;; =============== CALENDAR ===============
;; ========================================

(setq calendar-week-start-day 1
      calendar-latitude 48.1119800
      calendar-longitude -1.6742900
      calendar-location-name "Rennes, France")


;; ========================================
;; =============== OLIVETTI ===============
;; ========================================

(require 'olivetti)

(setq-default olivetti-body-width 0.6
	      olivetti-minimum-body-width 80)

(defun zp/olivetti-toggle-hide-mode-line ()
  (interactive)
  (olivetti-toggle-hide-mode-line)
  (toggle-frame-fullscreen)
  ;; (mode-line-other-buffer)
  ;; (mode-line-other-buffer)
  )

(define-key olivetti-mode-map (kbd "M-I") 'zp/olivetti-toggle-hide-mode-line)

;; (add-hook 'olivetti-mode-hook #'electric-quote-local-mode)
;; (setq olivetti-mode-hook nil)



;; ========================================
;; ============== ORG-AGENDA ==============
;; ========================================

(setq org-agenda-todo-ignore-with-date nil
      org-agenda-todo-ignore-scheduled 'future
      ;; org-agenda-show-future-repeats 'next
      org-agenda-show-future-repeats t
      ;; org-agenda-todo-ignore-scheduled 'past
      org-agenda-todo-ignore-deadlines nil
      org-agenda-include-deadlines 'all
      zp/projects-include-waiting nil
      zp/org-agenda-include-scheduled 'all
      org-agenda-cmp-user-defined 'zp/org-agenda-sort-special
      zp/org-agenda-sorting-strategy-user-defined 'special
      org-agenda-window-setup 'current-window
      org-deadline-warning-days 14
      org-agenda-tags-todo-honor-ignore-options 1
      org-agenda-compact-blocks nil
      org-agenda-todo-list-sublevels t
      org-agenda-dim-blocked-tasks t
      org-agenda-skip-scheduled-if-done 1
      org-agenda-skip-timestamp-if-done 1
      org-agenda-skip-deadline-if-done 1
      org-agenda-entry-text-maxlines 10
      org-agenda-use-time-grid nil
      org-agenda-sticky 1
      org-agenda-block-separator 126
      org-clock-report-include-clocking-task t
      org-agenda-exporter-settings
      '((ps-print-color-p t)
	(ps-landscape-mode t)
	(ps-print-header nil)
	(ps-default-bg t))
      org-agenda-clockreport-parameter-plist '(:link t :maxlevel 2 :fileskip0 t)
      )



(defun zp/update-org-agenda-files ()
  (interactive)
  (setq zp/org-agenda-files-main (append zp/org-agenda-files-life
					 zp/org-agenda-files-projects
					 zp/org-agenda-files-music
					 zp/org-agenda-files-sports))

  (setq org-agenda-files (append zp/org-agenda-files-main
				 zp/org-agenda-files-tools
				 zp/org-agenda-files-media))

  (zp/set-shortcuts-all))
(zp/update-org-agenda-files)



;; ========================================
;; =============== SORTING ================
;; ========================================

(defun org-cmp-test-todo (todo a b)
  "Compare the todo states of strings A and B."
  (let* ((ma (or (get-text-property 1 'org-marker a)
		 (get-text-property 1 'org-hd-marker a)))
	 (mb (or (get-text-property 1 'org-marker b)
		 (get-text-property 1 'org-hd-marker b)))
	 (fa (and ma (marker-buffer ma)))
	 (fb (and mb (marker-buffer mb)))
	 (todo-kwds
	  (or (and fa (with-current-buffer fa org-todo-keywords-1))
	      (and fb (with-current-buffer fb org-todo-keywords-1))))
	 (ta (or (get-text-property 1 'todo-state a) ""))
	 (tb (or (get-text-property 1 'todo-state b) ""))
	 (la (- (length (member ta todo-kwds))))
	 (lb (- (length (member tb todo-kwds))))
	 (donepa (member ta org-done-keywords-for-agenda))
	 (donepb (member tb org-done-keywords-for-agenda)))
    (cond ((and (string-match-p ta todo) (not (string-match-p tb todo))) +1)
	  ((and (string-match-p tb todo) (not (string-match-p ta todo))) -1))))

(defun zp/org-agenda-sort-special (a b)
  (cond
   ((org-cmp-test-todo "WAIT|STBY" a b))
   ((org-cmp-test-todo "STRT" a b))))

(defun zp/org-agenda-sort-wait (a b)
  (cond
   ((org-cmp-test-todo "WAIT|STBY" a b))))



;; ========================================
;; =============== HEADERS ================
;; ========================================

(defun zp/org-agenda-format-header-align (header)
  (let ((tags-column org-agenda-tags-column))
    (format
     (concat
      "%"
      (number-to-string
       (/ (+ (- tags-column) (length header)) 2))
      "s")
     header)))

(defun zp/org-agenda-format-word-list (word-list)
  (let ((word-list-linked (s-join ";" word-list)))
    (if (not (eq word-list nil))
	(concat " " "(" word-list-linked ")"))))

(defun zp/org-agenda-format-header-main (header)
  "Format the main header block in org-agenda."
  (let* ((tags-column org-agenda-tags-column)
	 (flanking-symbol "~")
	 (header-formatted
	  (zp/org-agenda-format-header-align
	   (concat flanking-symbol " " header " " flanking-symbol)))
	 (word-list ()))
    (if (eq org-agenda-dim-blocked-tasks nil)
    	(add-to-list 'word-list "-dim" t))
    (if (eq org-agenda-include-deadlines nil)
    	(add-to-list 'word-list "-deadlines" t))
    (if (eq org-habit-show-habits nil)
    	(add-to-list 'word-list "-habits" t))
    (if (eq zp/org-agenda-include-scheduled nil)
    	(add-to-list 'word-list "-scheduled" t))
    (let ((word-list-formatted (s-join ";" word-list)))
      (if (not (eq word-list nil))
	  (setq word-list-formatted (concat " " "(" word-list-formatted ")")))
      (concat
       header-formatted word-list-formatted "\n"))))

(defun zp/org-agenda-format-header-block (header)
  "Format header blocks in org-agenda."
  (let* ((tags-column org-agenda-tags-column)
	 (header-formatted (zp/org-agenda-format-header-align header)))
    (concat
     header-formatted "\n")))

(defun zp/org-agenda-format-header-block-with-settings (header)
  "Format header blocks in org-agenda, and display important
agenda settings after them."
  (let ((word-list ()))
    (if (eq zp/org-agenda-sorting-strategy-user-defined 'priority)
    	(add-to-list 'word-list "+#↓" t))
    (if (eq org-agenda-dim-blocked-tasks nil)
    	(add-to-list 'word-list "-dim" t))
    (if (eq org-agenda-todo-ignore-scheduled 'future)
    	(add-to-list 'word-list "-future" t))
    (let ((header-formatted (zp/org-agenda-format-header-align header))
	  (word-list-formatted (zp/org-agenda-format-word-list word-list)))
      (concat header-formatted word-list-formatted "\n"))))

;; Special blocks
(defun zp/org-agenda-format-header-projects-stuck ()
  "Format headers of ‘Stuck Projects’ in org-agenda, and display important
agenda settings after them."
  (let* ((tags-column org-agenda-tags-column)
	 (flanking-symbol-left "[")
	 (flanking-symbol-right "]")
	 (header "Stuck Projects")
	 (header-formatted
	  (zp/org-agenda-format-header-align
	   (concat flanking-symbol-left " " header " " flanking-symbol-right)))
	 (word-list ()))
    (if (eq org-agenda-dim-blocked-tasks nil)
    	(add-to-list 'word-list "-dim" t))
    (let ((word-list-formatted (zp/org-agenda-format-word-list word-list)))
      (concat header-formatted word-list-formatted "\n"))))

(defun zp/org-agenda-format-header-scheduled ()
  "Format headers of ‘Scheduled’ in org-agenda, and display
important agenda settings after them."
  (let* ((tags-column org-agenda-tags-column)
	 (header "Scheduled")
	 (word-list ()))
    (if (eq zp/org-agenda-sorting-strategy-user-defined 'priority)
    	(add-to-list 'word-list "+#↓" t))
    (if (eq org-agenda-dim-blocked-tasks nil)
    	(add-to-list 'word-list "-dim" t))
    (if (eq org-agenda-todo-ignore-scheduled 'future)
    	(add-to-list 'word-list "-future" t))
    (if (eq org-agenda-todo-ignore-scheduled nil)
    	(add-to-list 'word-list "+future" t))
    (let ((header-formatted (zp/org-agenda-format-header-align header))
	  (word-list-formatted (zp/org-agenda-format-word-list word-list)))
      (concat header-formatted word-list-formatted "\n"))))

(defun zp/org-agenda-format-header-projects ()
  "Format header blocks in org-agenda, and display important
agenda settings after them."
  (let* ((tags-column org-agenda-tags-column)
	 (header "Projects")
	 (word-list ()))
    (if (eq zp/org-agenda-sorting-strategy-user-defined 'priority)
    	(add-to-list 'word-list "+#↓" t))
    (if (eq zp/projects-include-waiting nil)
    	(add-to-list 'word-list "-waiting" t))
    (let ((header-formatted (zp/org-agenda-format-header-align header))
	  (word-list-formatted (zp/org-agenda-format-word-list word-list)))
      (concat header-formatted word-list-formatted "\n"))))



;; ========================================
;; ================ BLOCKS ================
;; ========================================

(defun zp/org-agenda-block-agenda (header &optional file)
  `(agenda ""
	   ((org-agenda-overriding-header
	     (zp/org-agenda-format-header-main ,header))
	    ,@(if (bound-and-true-p file)
		  `((org-agenda-files ',file)))
	    (org-agenda-span 'day)
	    (org-agenda-dim-blocked-tasks 'dimmed))))

(defun zp/org-agenda-block-agenda-week (header &optional file)
  `(agenda ""
	   ((org-agenda-overriding-header
	     (zp/org-agenda-format-header-main ,header))
	    ,@(if (bound-and-true-p file)
		  `((org-agenda-files ',file)))
	    (org-agenda-span 'week)
	    (org-agenda-tag-filter-preset '("-recurring"))
	    (org-agenda-skip-function
	     '(org-agenda-skip-entry-if
	       'todo '("CXLD")))
	    (org-agenda-dim-blocked-tasks 'dimmed))))

(defun zp/org-agenda-block-tasks (&optional file)
  `(tags-todo "-recurring-standby-reading"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-block-with-settings "Tasks"))
	       ,@(if (bound-and-true-p file)
		     `((org-agenda-files ',file)))
	       (org-agenda-sorting-strategy
		'(user-defined-down priority-down category-keep))
	       ;; (org-agenda-skip-function 'zp/skip-non-tasks-and-scheduled))))
	       (org-agenda-skip-function 'bh/skip-non-tasks)
	       (org-agenda-todo-ignore-scheduled 'all)
	       )))

(defun zp/org-agenda-block-projects-stuck (&optional file)
  (let ((org-agenda-cmp-user-defined 'org-cmp-todo-state-wait))
    `(tags-todo "-standby"
		((org-agenda-overriding-header
		  (zp/org-agenda-format-header-projects-stuck))
		 ,@(if (bound-and-true-p file)
		       `((org-agenda-files ',file)))
		 (org-agenda-skip-function 'zp/skip-non-stuck-projects)
		 (org-agenda-todo-ignore-scheduled nil)
		 (org-agenda-dim-blocked-tasks 'dimmed)))))

(defun zp/org-agenda-block-projects (&optional file)
  `(tags-todo "-standby-reading"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-projects))
	       ,@(if (bound-and-true-p file)
		     `((org-agenda-files ',file)))
	       (org-agenda-skip-function 'zp/skip-non-projects-and-waiting)
	       (org-agenda-sorting-strategy
		'(user-defined-down priority-down category-keep))
	       (org-agenda-todo-ignore-scheduled nil)
	       (org-agenda-dim-blocked-tasks nil))))

(defun zp/org-agenda-block-tasks-special (&optional file)
  `(tags-todo "-standby/!WAIT|STRT"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-tasks-waiting))
	       ,@(if (bound-and-true-p file)
		     `((org-agenda-files ',file)))
	       (org-agenda-skip-function 'bh/skip-non-tasks))))

(defun zp/org-agenda-block-scheduled (&optional file)
  `(tags-todo "-recurring-reading"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-scheduled))
	       ,@(if (bound-and-true-p file)
		     `((org-agenda-files ',file)))
	       (org-agenda-skip-function
		'(org-agenda-skip-entry-if 'notscheduled))
	       (org-agenda-dim-blocked-tasks 'dimmed)
	       (org-agenda-sorting-strategy '(timestamp-up user-defined-down priority-down)))))

(defun zp/org-agenda-block-tasks-waiting (&optional file)
  `(tags-todo "-recurring-reading/!WAIT"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-main "Waiting & Stand-by Tasks"))
	       ,@(if (bound-and-true-p file)
		     `((org-agenda-files ',file)))
	       ;; (org-agenda-skip-function
	       ;; 	'(org-agenda-skip-entry-if 'notscheduled))
	       (org-agenda-dim-blocked-tasks 'dimmed)
	       (org-agenda-sorting-strategy '(timestamp-up user-defined-down priority-down)))))

(defun zp/org-agenda-block-deadines ()
  '(agenda ""
	   ((org-agenda-span 'day)
	    (org-agenda-overriding-header
	     (zp/org-agenda-format-header-main "Deadlines"))
	    (org-agenda-entry-types '(:deadline))
	    (org-agenda-include-deadlines t)
	    (org-agenda-dim-blocked-tasks 'dimmed)
	    (org-deadline-warning-days 31)
	    (org-agenda-sorting-strategy
	     '((agenda habit-down time-up deadline-up priority-down category-keep)
	       (tags priority-down category-keep)
	       (todo priority-down category-keep)
	       (search category-keep))))))

(defun zp/org-agenda-block-reading-next-and-started ()
  '(tags-todo "+reading-recurring-standby/!NEXT|STRT"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-block "Next & Started")))))

(defun zp/org-agenda-block-reading-list ()
  '(tags-todo "+reading-recurring-standby/!-NEXT-STRT"
	      ((org-agenda-overriding-header
		(zp/org-agenda-format-header-block "Next & Started")))))

(defun zp/org-agenda-block-journal ()
  '(agenda ""
	   ((org-agenda-overriding-header
	     (zp/org-agenda-format-header-main "Journal")))))



(setq org-agenda-custom-commands
      `(("N" "Agenda"
	 (,(zp/org-agenda-block-agenda "Agenda" org-agenda-files))
	 ((org-agenda-files zp/org-agenda-files-main)))

	("n" "Task List"
	 (,(zp/org-agenda-block-projects)
	  ,(zp/org-agenda-block-projects-stuck)
	  ,(zp/org-agenda-block-scheduled)
	  ,(zp/org-agenda-block-tasks))
	 ((org-agenda-files zp/org-agenda-files-main)))

	("k" "Agenda:week (-recurring)"
	 (,(zp/org-agenda-block-agenda-week "Weekly Agenda")))

	("j" "Journal entries"
	 (,(zp/org-agenda-block-journal))
	 ((org-agenda-files zp/org-agenda-files-journals)))

	("r" "Reading (-standby)"
	 (,(zp/org-agenda-block-agenda "Reading")
	  ;; ,(zp/org-agenda-block-projects-stuck)
	  ,(zp/org-agenda-block-reading-next-and-started)
	  ,(zp/org-agenda-block-reading-list))
	 ((org-agenda-tag-filter-preset (list "+reading"))
	  (org-agenda-hide-tags-regexp "reading")
	  (org-agenda-files zp/org-agenda-files-main)
	  ))

	("b" "Media"
	 (,(zp/org-agenda-block-agenda "Media")
	  ,(zp/org-agenda-block-projects)
	  ,(zp/org-agenda-block-projects-stuck)
	  ,(zp/org-agenda-block-scheduled)
	  ,(zp/org-agenda-block-tasks))
	 ((org-agenda-files zp/org-agenda-files-media)))

	("l" "Arch & Emacs"
	 (,(zp/org-agenda-block-agenda "Arch & Emacs")
	  ,(zp/org-agenda-block-projects)
	  ,(zp/org-agenda-block-projects-stuck)
	  ,(zp/org-agenda-block-scheduled)
	  ,(zp/org-agenda-block-tasks))
	 ((org-agenda-files zp/org-agenda-files-tools)))

	("d" "Deadlines"
	 (,(zp/org-agenda-block-deadines)))

	("w" "Waiting list"
	 (,(zp/org-agenda-block-tasks-waiting))
	 ((org-agenda-files zp/org-agenda-files-main)
	  (org-agenda-todo-ignore-scheduled nil)))

	("S" "Swimming schedule"
	 ((agenda ""
		  ((org-agenda-files zp/org-agenda-files-sports))))
	 ((org-agenda-skip-timestamp-if-done nil)))))

;; Example for layers
;; ("h" . "Test")
;; ("he" . "Another test")
;; ("hec" tags "+home")


(setq org-agenda-prefix-format '((agenda . " %i %-12:c%?-12t% s")
				 (timeline . "  % s")
				 (todo . " %i %-12:c")
				 (tags . " %i %-12:c")
				 ;; (tags . " %i %-12:c %?-12t% s")
				 ;; (tags . " %i %-12:c %-12b ")
				 ;; (tags . " %i %-12:c %l ")
				 ;; (tags . " %i %-12:c %-40:(concat \"[\"(org-format-outline-path (org-get-outline-path)) \"]\") ")
				 ;; (tags . " %i %-12:c %s %(if (not (list (nth 1 (org-get-outline-path)))) (org-format-outline-path(concat \"[\"(org-format-outline-path (list (nth 1 (org-get-outline-path)))) \"]\"))) ")
				 (search . " %i %-12:c")))



;; (setq org-agenda-sorting-strategy
(setq org-agenda-sorting-strategy '((agenda habit-down time-up scheduled-up deadline-up priority-down category-keep)
				    (tags priority-down category-keep)
				    ;; (tags category-keep priority-down)
				    (todo priority-down category-keep)
				    (search category-keep)))

;; Previous priority for agenda
;; '((agenda habit-down time-up priority-down category-keep)



;; Cumulate TODO-keywords
;; Remember the `|'
;; (tags-todo "+TODO=\"NEXT\"|+TODO=\"STARTED\"")

;; Prototype for inserting colours
;; (insert (propertize "Test" 'font-lock-face '(:foreground "green" :background "gray6")))

(defun zp/org-agenda-delete-empty-blocks ()
  "Remove empty agenda blocks.
  A block is identified as empty if there are fewer than 2
  non-empty lines in the block (excluding the line with
  `org-agenda-block-separator' characters)."
  (when org-agenda-compact-blocks
    (user-error "Cannot delete empty compact blocks"))
  (setq buffer-read-only nil)
  (save-excursion
    (goto-char (point-min))
    (let* ((blank-line-re "^\\s-*$")
	   (content-line-count (if (looking-at-p blank-line-re) 0 1))
	   (start-pos (point))
	   (block-re (format "%c\\{10,\\}" org-agenda-block-separator)))
      (while (and (not (eobp)) (forward-line))
	(cond
	 ((looking-at-p block-re)
	  (when (< content-line-count 2)
	    (delete-region start-pos (1+ (point-at-bol))))
	  (setq start-pos (point))
	  (forward-line)
	  (setq content-line-count (if (looking-at-p blank-line-re) 0 1)))
	 ((not (looking-at-p blank-line-re))
	  (setq content-line-count (1+ content-line-count)))))
      (when (< content-line-count 2)
	(delete-region start-pos (point-max)))
      (goto-char (point-min))
      ;; The above strategy can leave a separator line at the beginning
      ;; of the buffer.
      (when (looking-at-p block-re)
	(delete-region (point) (1+ (point-at-eol))))))
  (setq buffer-read-only t))

(defface zp/org-agenda-block-info-face nil
  "Info for blocked faces in org-agenda.")

(defface zp/org-agenda-block-warning-face nil
  "Warning for blocked faces in org-agenda.")

(defun zp/org-agenda-hi-lock ()
  (highlight-regexp "([-+].*?)" 'zp/org-agenda-block-info-face)
  (highlight-regexp "^[[:space:]]*? \\[ Stuck Projects \\]" 'zp/org-agenda-block-warning-face)
  (highlight-regexp "^~~.*~~$" 'font-lock-comment-face))

(defun zp/org-agenda-remove-mouse-face ()
  "Remove mouse-face from org-agenda."
  (remove-text-properties(point-min) (point-max) '(mouse-face t)))

(add-hook 'org-agenda-finalize-hook #'zp/org-agenda-hi-lock)
(add-hook 'org-agenda-finalize-hook #'zp/org-agenda-delete-empty-blocks)
(add-hook 'org-agenda-finalize-hook #'zp/org-agenda-remove-mouse-face)

;; Good example for a toggle based on variables
(defun zp/toggle-org-habit-show-all-today ()
  "Toggle the display of habits between showing only the habits due today, and showing all of them."
  (interactive)
  (cond ((bound-and-true-p org-habit-show-all-today)
         (setq org-habit-show-all-today nil)
	 (org-agenda-redo)
	 (message "Habits: Showing today"))
        (t
         (setq org-habit-show-all-today 1)
	 (org-agenda-redo)
	 (message "Habits: Showing all"))))

(defun zp/toggle-org-agenda-include-deadlines ()
  "Toggle the inclusion of deadlines in the agenda."
  (interactive)
  (cond ((bound-and-true-p org-agenda-include-deadlines)
         (setq org-agenda-include-deadlines nil)
	 (org-agenda-redo)
	 (message "Deadlines: Hidden"))
        (t
         (setq org-agenda-include-deadlines t)
	 (org-agenda-redo)
	 (message "Deadlines: Visible"))))

(defun zp/toggle-org-agenda-include-scheduled ()
  "Toggle the inclusion of scheduled items in the agenda."
  (interactive)
  (cond ((eq zp/org-agenda-include-scheduled 'all)
         (setq org-agenda-entry-types '(:deadline :timestamp :sexp)
	       zp/org-agenda-include-scheduled nil)
	 (org-agenda-redo)
	 (message "Scheduled: Hidden"))
        (t
         (setq org-agenda-entry-types '(:deadline :scheduled :timestamp :sexp)
	       zp/org-agenda-include-scheduled 'all)
	 (org-agenda-redo)
	 (message "Scheduled: Visible"))))

(defun zp/toggle-org-agenda-cmp-user-defined ()
  "Toggle the skip function used by the agenda."
  (interactive)
  (cond ((eq zp/org-agenda-sorting-strategy-user-defined 'priority)
         (setq org-agenda-cmp-user-defined 'zp/org-agenda-sort-special
	       zp/org-agenda-sorting-strategy-user-defined 'special)
	 (org-agenda-redo)
	 (message "Sorting: Special first"))
        (t
         (setq org-agenda-cmp-user-defined 'zp/org-agenda-sort-wait
	       zp/org-agenda-sorting-strategy-user-defined 'priority)
	 (org-agenda-redo)
	 (message "Sorting: Priority first"))))

(defun zp/toggle-org-deadline-warning-days-range ()
  "Toggle the range of days for deadline to show up on the agenda."
  (interactive)
  (cond ((eq org-deadline-warning-days 7)
	 (setq org-deadline-warning-days 31)
	 (org-agenda-redo)
	 (message "Deadline range: 1 month"))
	((eq org-deadline-warning-days 31)
	 (setq org-deadline-warning-days 7)
	 (org-agenda-redo)
	 (message "Deadline range: 1 week"))))

(defun zp/toggle-org-agenda-todo-ignore-future-scheduled ()
  "Toggle the range of days for deadline to show up on the agenda."
  (interactive)
  (cond ((eq org-agenda-todo-ignore-scheduled 'future)
	 (setq org-agenda-todo-ignore-scheduled nil)
	 (org-agenda-redo)
	 (message "Scheduled: All (Today + Future)"))
	((eq org-agenda-todo-ignore-scheduled nil)
	 (setq org-agenda-todo-ignore-scheduled 'future)
	 (org-agenda-redo)
	 (message "Scheduled: Only Today"))))

(defun zp/toggle-org-agenda-projects-include-waiting ()
  "Toggle whether to include projects with a waiting task."
  (interactive)
  (cond ((eq zp/projects-include-waiting nil)
	 (setq zp/projects-include-waiting t)
	 (org-agenda-redo)
	 (message "Projects: Showing All"))
	((eq zp/projects-include-waiting t)
	 (setq zp/projects-include-waiting nil)
	 (org-agenda-redo)
	 (message "Projects: Hiding Waiting"))))

(defun zp/toggle-org-agenda-dim-blocked-tasks ()
  "Toggle the dimming of blocked tags in the agenda."
  (interactive)
  (cond ((or (eq org-agenda-dim-blocked-tasks nil)
	     (eq org-agenda-dim-blocked-tasks 'invisible))
         (setq org-agenda-dim-blocked-tasks t)
	 (org-agenda-redo)
	 (message "Blocked tasks: Dimmed"))
        (t
         (setq org-agenda-dim-blocked-tasks nil)
	 (org-agenda-redo)
	 (message "Blocked tasks: Plain"))))

(defun zp/toggle-org-agenda-hide-blocked-tasks ()
  "Toggle the visibility of blocked tags in the agenda."
  (interactive)
  (cond ((or (eq org-agenda-dim-blocked-tasks nil)
	     (eq org-agenda-dim-blocked-tasks t))
         (setq org-agenda-dim-blocked-tasks 'invisible)
	 (org-agenda-redo)
	 (message "Blocked tasks: Invisible"))
        (t
         (setq org-agenda-dim-blocked-tasks t)
	 (org-agenda-redo)
	 (message "Blocked tasks: Dimmed"))))

;; Dangerous, since it might hide important tasks to do.
;; (defun zp/org-tags-match-list-sublevels ()
;;   "Toggle the inclusion of sublevels TODO in the agenda.."
;;   (interactive)
;;   (cond ((bound-and-true-p org-tags-match-list-sublevels)
;;          (setq org-tags-match-list-sublevels nil)
;; 	 (org-agenda-redo)
;; 	 (message "Subtasks: Hidden"))
;;         (t
;;          (setq org-tags-match-list-sublevels t)
;; 	 (org-agenda-redo)
;; 	 (message "Subtasks: Showing"))))

;; (defun zp/toggle-org-agenda-dim-blocked-tasks ()
;;   "Toggle a distraction-free environment for writing."
;;   (interactive)
;;   (cond ((eq org-agenda-dim-blocked-tasks 'invisible)
;;          (setq org-agenda-dim-blocked-tasks nil)
;; 	 (org-agenda-redo)
;; 	 (message "Blocked tasks: Plain"))
;; 	((eq org-agenda-dim-blocked-tasks nil)
;;          (setq org-agenda-dim-blocked-tasks t)
;; 	 (org-agenda-redo)
;; 	 (message "Blocked tasks: Dimmed"))
;; 	((eq org-agenda-dim-blocked-tasks t)
;; 	 (setq org-agenda-dim-blocked-tasks 'invisible)
;; 	 (org-agenda-redo)
;; 	 (message "Blocked tasks: Invisible"))
;;         ))

(defun zp/org-agenda-set-property (property-function)
  "Set a property for the current headline in the agenda.
Based on `org-agenda-set-property'."
  (interactive)
  (org-agenda-check-no-diary)
  (let* ((hdmarker (or (org-get-at-bol 'org-hd-marker)
		       (org-agenda-error)))
	 (buffer (marker-buffer hdmarker))
	 (pos (marker-position hdmarker))
	 (inhibit-read-only t)
	 newhead)
    (org-with-remote-undo buffer
      (with-current-buffer buffer
	(widen)
	(goto-char pos)
	(org-show-context 'agenda)
	(call-interactively property-function)))))

(defun zp/org-agenda-delete-property ()
  "Delete a property for the current headline in the agenda."
  (interactive)
  (zp/org-agenda-set-property 'org-delete-property))

(defun zp/org-set-appt-warntime ()
  "Set the `APPT_WARNTIME' property."
  (interactive)
  (org-set-property "APPT_WARNTIME" (org-read-property-value "APPT_WARNTIME")))
(defun zp/org-agenda-set-appt-warntime ()
  "Set the `APPT_WARNTIME' for the current entry in the agenda."
  (interactive)
  (zp/org-agenda-set-property 'zp/org-set-appt-warntime))

(defun zp/org-set-location ()
  "Set the `LOCATION' property."
  (interactive)
  (org-set-property "LOCATION" (org-read-property-value "LOCATION")))
(defun zp/org-agenda-set-location ()
  "Set the `LOCATION' for the current entry in the agenda."
  (interactive)
  (zp/org-agenda-set-property 'zp/org-set-location))

(defun zp/org-agenda-mode-config ()
  "For use with `org-agenda-mode'."
  (local-set-key (kbd "k") 'zp/org-agenda-capture)
  (local-set-key (kbd "C-,") 'sunrise-sunset)
  (local-set-key (kbd "M-k") 'zp/toggle-org-habit-show-all-today)
  (local-set-key (kbd "M-t") 'org-agenda-todo-yesterday)
  (local-set-key (kbd "D") 'zp/toggle-org-agenda-include-deadlines)
  (local-set-key (kbd "S") 'zp/toggle-org-agenda-include-scheduled)
  (local-set-key (kbd "M-d") 'zp/toggle-org-deadline-warning-days-range)
  (local-set-key (kbd "h") 'zp/toggle-org-agenda-cmp-user-defined)
  (local-set-key (kbd "H") 'zp/toggle-org-agenda-dim-blocked-tasks)
  (local-set-key (kbd "F") 'zp/toggle-org-agenda-todo-ignore-future-scheduled)
  (local-set-key (kbd "W") 'zp/toggle-org-agenda-projects-include-waiting)
  (local-set-key (kbd "C-c C-x r") 'zp/org-agenda-set-appt-warntime)
  (local-set-key (kbd "C-c C-x l") 'zp/org-agenda-set-location)
  (local-set-key (kbd "C-c C-x d") 'zp/org-agenda-delete-property)
  ;; (local-set-key (kbd "C-c C-w") 'zp/org-agenda-refile)
  (local-set-key (kbd "C-c C-S-w") 'zp/org-agenda-refile-with-paths)
  (local-set-key (kbd "Z") 'org-resolve-clocks)
  (local-set-key (kbd "C-<return>") 'org-agenda-switch-to)
  (local-set-key (kbd "<return>") 'zp/org-agenda-tree-to-indirect-buffer-without-grabbing-focus)
  (local-set-key (kbd "S-<return>") 'zp/org-agenda-tree-to-indirect-buffer)
  (local-set-key (kbd "M-<return>") 'zp/org-agenda-tree-to-indirect-buffer-maximise)
  (local-set-key (kbd "<backspace>") 'zp/org-agenda-kill-other-buffer-and-window))

(add-hook 'org-agenda-mode-hook 'zp/org-agenda-mode-config)



(defun zp/unfill-document ()
  "fill individual paragraphs with large fill column"
  (interactive)
  (let ((fill-column 100000))
    (fill-individual-paragraphs (point-min) (point-max))))

(defun zp/unfill-paragraph ()
  (interactive)
  (let ((fill-column (point-max)))
    (fill-paragraph nil)))

(defun zp/unfill-region ()
  (interactive)
  (let ((fill-column (point-max)))
    (fill-region (region-beginning) (region-end) nil)))

(defun zp/unfill-context ()
  (interactive)
  (if (region-active-p)
      (zp/unfill-region)
    (zp/unfill-paragraph)))



;; ========================================
;; ============= ORG-CAPTURE ==============
;; ========================================

(setq org-default-notes-file "/home/zaeph/org/life.org.gpg")
(setq org-capture-templates
      '(("n" "Note" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* %?")
	("f" "Todo" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?")
	("r" "Todo + Context" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\n%a")
	;; ("r" "Todo + Reminder" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* TODO %?\nSCHEDULED: %^T\n:PROPERTIES:\n:APPT_WARNTIME:  %^{APPT_WARNTIME|5|15|30|60}\n:END:")
	;; ("T" "Todo (with keyword selection)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* %^{State|TODO|NEXT|STBY|WAIT} %?")
	;; ("e" "Todo + Creation time" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* TODO %?\n:PROPERTIES:\n:CREATED:  %U\n:END:")
	;; ("C" "Todo + Clock" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* TODO %^{Task}%?" :clock-in t)
	;; ("C" "Todo + Clock (with keyword selection)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* %^{State|TODO|NEXT} %?" :clock-in t)
	("d" "Date" entry (file+headline "/home/zaeph/org/life.org.gpg" "Calendar")
	 "* %?\n")
	("e" "Date + Context" entry (file+headline "/home/zaeph/org/life.org.gpg" "Calendar")
	 "* %?\n%a")

	;; ("D" "Date + Reminder" entry (file+headline "/home/zaeph/org/life.org.gpg" "Calendar")
	;;  "* %?\n%^T\n\n%^{APPT_WARNTIME}p")
	;; ("R" "Reminder" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	;;  "* %?\n%^T%^{APPT_WARNTIME}p")

	("p" "Phone-call" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO Phone-call with %^{Interlocutor|Nicolas|Mum}%?\n:STATES:\n- State \"TODO\"       from              %U\n:END:" :clock-in t)
	("m" "Meeting" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO Meeting with %^{Meeting with}%?" :clock-in t)

	("j" "Journal")
	("jj" "Journal" entry (file "/home/zaeph/org/journal.org.gpg")
	 "* %^{Title|Entry}\n%T\n\n%?" :empty-lines 1)
	("jw" "Writing" entry (file "/home/zaeph/org/projects/writing/journal.org.gpg")
	 "* %^{Title|Entry} %^g\n%T\n\n%?" :empty-lines 1)
	("jr" "Research" entry (file "/home/zaeph/org/projects/university/research/journal.org.gpg")
	 "* %^{Title|Entry}\n%T\n\n%?" :empty-lines 1)
	("ju" "University" entry (file "/home/zaeph/org/projects/university/journal.org.gpg")
	 "* %^{Title|Entry}\n%T\n\n%?" :empty-lines 1)	("jl" "Programming" entry (file "/home/zaeph/org/projects/arch-linux/journal.org.gpg")
	 "* %^{Title|Entry}\n%T\n\n%?" :empty-lines 1)
	("js" "Swimming" entry (file "/home/zaeph/org/sports/swimming/journal.org.gpg")
	 "* %^{Title|Entry}\n%T\n\n%?" :empty-lines 1)
      	;; ("s" "Swimming workout" entry (file+olp "/home/zaeph/org/life.org.gpg" "Sports" "Swimming" "Records" "Current")
	("s" "Swimming workout" entry (file+weektree+prompt "/home/zaeph/org/sports/swimming/swimming.org.gpg")
	 "* DONE Training%^{SWIM_DISTANCE}p%^{SWIM_DURATION}p\n%t%(print zp/swimming-workout-default)")))

(defvar zp/swimming-workout-default nil)
(setq zp/swimming-workout-default "
|-----+---------------------------|
| 500 | warmup crawl/fly          |
| 500 | pull tech                 |
| 500 | 50 crawl fast / 100 crawl |
| 500 | 100 pull / 100 pull fast  |
| 500 | 50 fly / 100 crawl        |
| 500 | 100 pull / 100 pull fast  |
| 500 | 50 fly / 100 crawl        |
| 100 | warmdown                  |
|-----+---------------------------|")

(setq zp/org-agenda-capture-templates
      '(("f" "Todo" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\n%t")
	("r" "Todo (+time)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\n%^T")

	("d" "Date" entry (file+headline "/home/zaeph/org/life.org.gpg" "Calendar")
	 "* %?\n%t")
	("e" "Date (+time)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Calendar")
	 "* %?\n%^T")

	("s" "Todo & Scheduled" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\nSCHEDULED: %t")
	("w" "Todo & Scheduled (+time)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\nSCHEDULED: %^T")

	("g" "Todo + Deadline" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\nDEADLINE: %t")
	("t" "Todo & Deadline (+time)" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
	 "* TODO %?\nDEADLINE: %^T")))

(defun zp/org-agenda-capture (&optional arg)
  (interactive "P")
  (let ((org-capture-templates zp/org-agenda-capture-templates))
    (org-agenda-capture arg)))



	;; ("v" "Vocabulary")
	;; ("ve" "EN" entry (file+olp "/home/zaeph/org/life.org.gpg" "Vocabulary")
	;;  "* EN: %?\n%U\n")
	;; ("vf" "FR" entry (file+olp "/home/zaeph/org/life.org.gpg" "Vocabulary")
	;;  "* FR: %?\n%U\n")
	;; ("vj" "JA" entry (file+olp "/home/zaeph/org/life.org.gpg" "Vocabulary")
	;;  "* JA: %?\n%U\n")
	;; ("vk" "KO" entry (file+olp "/home/zaeph/org/life.org.gpg" "Vocabulary")
	;;  "* KO: %?\n%U\n")))

;; ;; Empty lines before and after
;; (setq org-capture-templates
;;       '(("t" "Todo" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
;; 	 "* TODO %?" :empty-lines-before 1 :empty-lines-after 1)
;; 	("T" "Todo+" entry (file+headline "/home/zaeph/org/life.org.gpg" "Inbox")
;; 	 "* TODO %?\n%U\n%a\n" :empty-lines-before 1 :empty-lines-after 1)
;; 	("j" "Journal" entry (file+datetree "/home/zaeph/org/journal.org")
;; 	 "* %?\n%U\n")))

(defvar zp/org-capture-before-config nil
  "Window configuration before `org-capture'.")

(defadvice org-capture (before save-config activate)
  "Save the window configuration before `org-capture'."
  (setq zp/org-capture-before-config (current-window-configuration)))

(defun zp/org-capture-mode-delete-other-windows-if-journal ()
  "Maximise the capture frame if the destination file contains `journal'."
  (if (string-match-p (regexp-quote "journal") (buffer-name))
      (delete-other-windows)))

(add-hook 'org-capture-mode-hook 'zp/org-capture-mode-delete-other-windows-if-journal)



;; ========================================
;; ============== ORG-REFILE ==============
;; ========================================

(setq org-refile-targets '(
			   (nil :maxlevel . 9)
			   (org-agenda-files :maxlevel . 1)
			   (zp/org-agenda-files-life :maxlevel . 3)
			   )
      org-refile-use-cache nil)


(setq org-outline-path-complete-in-steps nil
      org-refile-use-outline-path nil)

(defun zp/org-refile-with-paths (&optional arg default-buffer rfloc msg)
  (interactive "P")
  (let ((org-refile-use-outline-path 1)
	(org-refile-targets
	 '((nil :maxlevel . 9)
	   (org-agenda-files :maxlevel . 3))))
    (org-refile arg default-buffer rfloc msg)))

(defun zp/org-agenda-refile (&optional arg default-buffer rfloc msg goto rfloc no-update)
  (interactive "P")
  (if current-prefix-arg
      (org-refile arg default-buffer rfloc msg)
    (org-agenda-refile goto rfloc no-update)))

(defun zp/org-agenda-refile-with-paths (&optional arg default-buffer rfloc msg goto rfloc no-update)
  (interactive "P")
  (let ((org-refile-use-outline-path 1)
	(org-refile-targets
	 '((nil :maxlevel . 9)
	   (org-agenda-files :maxlevel . 3))))
    (if current-prefix-arg
	(org-refile arg default-buffer rfloc msg)
      (org-agenda-refile goto rfloc no-update))))



(defun zp/org-refile-internal (file headline &optional arg)
  "Refile to a specific location.
With a 'C-u' ARG argument, we jump to that location (see
`org-refile').
Use `org-agenda-refile' in `org-agenda' mode."
  (let* ((pos (with-current-buffer (or (get-buffer file)	;Is the file open in a buffer already?
				       (find-file-noselect file)) ;Otherwise, try to find the file by name (Note, default-directory matters here if it isn't absolute)
		(or (org-find-exact-headline-in-buffer headline)
		    (error "Can't find headline `%s'" headline))))
	 (filepath (buffer-file-name (marker-buffer pos)));If we're given a relative name, find absolute path
	 (rfloc (list headline filepath nil pos)))
    (if (and (eq major-mode 'org-agenda-mode) (not (and arg (listp arg)))) ;Don't use org-agenda-refile if we're just jumping
	(org-agenda-refile nil rfloc)
      (org-refile arg nil rfloc))))

(defun zp/org-refile (file headline &optional arg)
  "Refile to HEADLINE in FILE. Clean up org-capture if it's activated.
With a `C-u` ARG, just jump to the headline."
  (interactive "P")
  (let ((is-capturing (and (boundp 'org-capture-mode) org-capture-mode)))
    (cond
     ((and arg (listp arg))	    ;Are we jumping?
      (zp/org-refile-internal file headline arg))
     ;; Are we in org-capture-mode?
     (is-capturing      	;Minor mode variable that's defined when capturing
      (zp/org-capture-refile-internal file headline arg))
     (t
      (zp/org-refile-internal file headline arg)))
    (when (or arg is-capturing)
      (setq hydra-deactivate t))))

(defun zp/org-capture-refile-internal (file headline &optional arg)
  "Copied from ‘org-capture-refile’ since it doesn't allow passing arguments. This does."
  (unless (eq (org-capture-get :type 'local) 'entry)
    (error
     "Refiling from a capture buffer makes only sense for `entry'-type templates"))
  (let ((pos (point))
	(base (buffer-base-buffer (current-buffer)))
	(org-capture-is-refiling t)
	(kill-buffer (org-capture-get :kill-buffer 'local)))
    (org-capture-put :kill-buffer nil)
    (org-capture-finalize)
    (save-window-excursion
      (with-current-buffer (or base (current-buffer))
	(org-with-wide-buffer
	 (goto-char pos)
	 (zp/org-refile-internal file headline arg))))
    (when kill-buffer (kill-buffer base))))

(defmacro zp/make-hydra-org-refile (hydraname file keyandheadline)
  "Make a hydra named HYDRANAME with refile targets to FILE.
KEYANDHEADLINE should be a list of cons cells of the form (\"key\" . \"headline\")"
  `(defhydra ,hydraname (:color blue :after-exit (unless (or hydra-deactivate
							     current-prefix-arg) ;If we're just jumping to a location, quit the hydra
						   (zp/hydra-org-refile/body)))
     ,file
     ,@(cl-loop for kv in keyandheadline
		collect (list (car kv) (list 'zp/org-refile file (cdr kv) 'current-prefix-arg) (cdr kv)))
     ("q" nil "cancel")))

;;;;;;;;;;
;; Here we'll define our refile headlines
;;;;;;;;;;

(zp/make-hydra-org-refile zp/hydra-org-refile-file-life
			    "/home/zaeph/org/life.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")
			     ("m" . "Maintenance")))

(zp/make-hydra-org-refile zp/hydra-org-refile-file-media
			    "/home/zaeph/org/media.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")
			     ("c" . "Calendar")))

(zp/make-hydra-org-refile zp/hydra-org-refile-file-university
			    "/home/zaeph/org/projects/university/university.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")
			     ("c" . "Calendar")))

(zp/make-hydra-org-refile zp/hydra-org-refile-file-research
			    "/home/zaeph/org/projects/university/research/research.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")))

(zp/make-hydra-org-refile zp/hydra-org-refile-file-emacs
			    "/home/zaeph/org/projects/emacs/emacs.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")
			     ("b" . "Troubleshooting")
			     ("c" . "Contributing")))

(zp/make-hydra-org-refile zp/hydra-org-refile-file-arch-linux
			    "/home/zaeph/org/projects/arch-linux/arch-linux.org.gpg"
			    (("i" . "Inbox")
			     ("t" . "Tasks")
			     ("b" . "Troubleshooting")
			     ("c" . "Contributing")
			     ("u" . "Utilities")
			     ("a" . "AUR")))



(defhydra zp/hydra-org-refile (:foreign-keys run)
  "Refile"
  ("o" zp/hydra-org-refile-file-life/body	"Life" :exit t)
  ("b" zp/hydra-org-refile-file-media/body	"Media" :exit t)
  ("u" zp/hydra-org-refile-file-university/body	"University" :exit t)
  ("r" zp/hydra-org-refile-file-research/body	"Research" :exit t)
  ("e" zp/hydra-org-refile-file-emacs/body	"Emacs" :exit t)
  ("l" zp/hydra-org-refile-file-arch-linux/body	"Arch Linux" :exit t)
  ("j" org-refile-goto-last-stored "Jump to last refile" :exit t)
  ("w" org-refile "zp/org-refile" :exit t)
  ("q" nil "cancel"))

(global-set-key (kbd "C-c C-w") 'zp/hydra-org-refile/body)
(define-key org-capture-mode-map (kbd "C-c C-w") 'zp/hydra-org-refile/body)
(define-key org-mode-map (kbd "C-c C-w") 'zp/hydra-org-refile/body)
(define-key org-agenda-mode-map (kbd "C-c C-w") 'zp/hydra-org-refile/body)



;; ========================================
;; ================= APPT =================
;; ========================================

(require 'appt)
(appt-activate t)

(setq appt-message-warning-time 15
      appt-display-interval 5
      appt-display-mode-line nil)
;; (setq appt-display-interval 1)


; Use appointment data from org-mode
(defun zp/org-agenda-to-appt ()
  (interactive)
  (setq appt-time-msg-list nil)
  (let ((inhibit-message t))
    (org-agenda-to-appt)))

(defun zp/org-agenda-to-appt-on-load ()
  "Hook to `org-agenda-finalize-hook' which creates the appt-list
on init and them removes itself."
  (zp/org-agenda-to-appt)
  (remove-hook 'org-agenda-finalize-hook 'zp/org-agenda-to-appt-on-load))

(defun zp/org-agenda-to-appt-on-save ()
  ;; (if (string= (buffer-file-name) (concat (getenv "HOME") "/org/life.org.gpg"))
  ;; (if (string< (buffer-file-name) "org.gpg")
  (if (member buffer-file-name org-agenda-files)
      (zp/org-agenda-to-appt)))


;; ----------------------------------------
;; Update reminders when...

;; Starting Emacs
;; (zp/org-agenda-to-appt)

;; Everyday at 12:05am
;; (run-at-time "12:05am" (* 24 3600) 'zp/org-agenda-to-appt)

;; When saving org-agenda-files
(add-hook 'after-save-hook 'zp/org-agenda-to-appt-on-save)

;; When (re)loading an agenda
(add-hook 'org-agenda-finalize-hook 'zp/org-agenda-to-appt-on-load)

;; ----------------------------------------
;; Remove hooks
;; (remove-hook 'after-save-hook 'zp/org-agenda-to-appt-on-save)
;; (remove-hook 'org-agenda-finalize-hook 'zp/org-agenda-to-appt)

;; ----------------------------------------

; Display appointments as a window manager notification
(setq appt-disp-window-function 'zp/appt-display)
(setq appt-delete-window-function (lambda () t))

;; (setq my-appt-notification-app (concat (getenv "HOME") "/bin/appt-notification"))
(setq zp/appt-notification-app "/home/zaeph/.bin/appt-notify")

(defun zp/appt-display (min-to-app new-time msg)
  (if (atom min-to-app)
    (start-process "zp/appt-notification-app" nil zp/appt-notification-app min-to-app msg)
  (dolist (i (number-sequence 0 (1- (length min-to-app))))
    (start-process "zp/appt-notification-app" nil zp/appt-notification-app (nth i min-to-app) (nth i msg)))))



;; ========================================
;; ================ MAGIT =================
;; ========================================

(require 'magit)
(setq magit-diff-refine-hunk 'all)



;; ========================================
;; =============== CHRONOS ================
;; ========================================

(require 'chronos)
(load "/home/zaeph/.emacs.d/lisp/helm-chronos-patched.el")
(require 'helm-chronos)  ;; Doesn't support creating new timers from helm

(setq chronos-expiry-functions '(chronos-notify))

(defun chronos-notify (c)
  "Notify expiration of timer C using custom script."
  (chronos--shell-command "Chronos notification"
                          "chronos-notify"
                          (list (chronos--time-string c)
                                (chronos--message c))))

;; Fix for adding new timers
(defvar helm-chronos--fallback-source
  (helm-build-dummy-source "Enter <expiry time spec>/<message>"
    :filtered-candidate-transformer
    (lambda (_candidates _source)
      (list (or (and (not (string= helm-pattern ""))
		     helm-pattern)
		"Enter a timer to start")))
    :action '(("Add timer" . (lambda (candidate)
			       (if (string= helm-pattern "")
				   (message "No timer")
				 (helm-chronos--parse-string-and-add-timer helm-pattern)))))))

(setq helm-chronos-recent-timers-limit 10
      helm-chronos-standard-timers
      '(
	"Green Tea		3/Green Tea: Remove tea bag"
	"Black Tea		4/Black Tea: Remove tea bag"
	"Herbal Tea		10/Herbal Tea: Remove tea bag"
	"Timebox		25/Finish and Reflect + 5/Back to it"
	"Break			30/Back to it"
	))

(defun zp/chronos-edit-selected-line-time (time prefix)
  (interactive)
  (interactive "sTime: \nP")
  (let ((c chronos--selected-timer))
    (when (chronos--running-or-paused-p c)
      (let ((ftime (chronos--parse-timestring time
                                              (if prefix
                                                  nil
                                                (chronos--expiry-time c)))))
            ;; (msg (read-from-minibuffer "Message: " (chronos--message c))))
        (chronos--set-expiry-time c ftime)
        ;; (chronos--set-message c msg)
        (chronos--set-action c (not (chronos--expiredp c)))
        (chronos--update-display)))))

(defun zp/chronos-edit-quick (time string)
  (interactive)
  (zp/chronos-edit-selected-line-time time nil)
  (if (string-match-p "-" time)
      (message (concat "Subtracted " string " from selected timer."))
    (message (concat "Added " string " to selected timer."))))

;; Hook
(defun chronos-mode-config ()
  "Modify keymaps used by `org-mode'."
  (local-set-key (kbd "u") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "-0:00:15" "15 s")))
  (local-set-key (kbd "i") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "+0:00:15" "15 s")))
  (local-set-key (kbd "j") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "-0:01:00" "1 min")))
  (local-set-key (kbd "k") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "+0:01:00" "1 min")))
  (local-set-key (kbd "J") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "-0:05:00" "5 min")))
  (local-set-key (kbd "K") (lambda ()
			     (interactive)
			     (zp/chronos-edit-quick "+0:05:00" "5 min")))
  (local-set-key (kbd "a") 'helm-chronos-add-timer))
(setq chronos-mode-hook 'chronos-mode-config)



;; ========================================
;; =========== WHITESPACE-MODE ============
;; ========================================

(defun zp/whitespace-mode-lines-tail ()
  (interactive)
  (if (bound-and-true-p whitespace-mode)
      (progn
	(whitespace-mode -1)
	(message "Whitespace mode disabled in current buffer"))
    (let ((whitespace-style '(face trailing lines-tail))
	  (whitespace-line-column 80))
      (whitespace-mode t)
      (message "Whitespace mode enabled in current buffer"))))



;; ========================================
;; ============== ORG-NOTER ===============
;; ========================================

;; (load "/home/zaeph/.emacs.d/lisp/org-noter-patched.el")
;; (load "/home/zaeph/.emacs.d/pkg/org-noter/org-noter.el")
(require 'org-noter)
(setq org-noter-hide-other t
      org-noter-auto-save-last-location t)

(add-hook #'org-noter-notes-mode-hook #'visual-line-mode)

;;; Fix for hiding truncation
(defun org-noter--set-notes-scroll (window &rest ignored)
  nil)

;; Fix for visual-line-mode with PDF files
(defun org-noter--note-after-tipping-point (point note-property view)
  nil)

;; -----------------------------------------------------------------------------
;;; Fix for truncation indicators in the margins
(el-patch-feature org-noter)
(with-eval-after-load 'org-noter
  (el-patch-defun org-noter--create-session (ast document-property-value notes-file-path)
		  (let* ((raw-value-not-empty (> (length (org-element-property :raw-value ast)) 0))
			 (display-name (if raw-value-not-empty
					   (org-element-property :raw-value ast)
					 (file-name-nondirectory document-property-value)))
			 (frame-name (format "Emacs Org-noter - %s" display-name))

			 (document (find-file-noselect document-property-value))
			 (document-path (expand-file-name document-property-value))
			 (document-major-mode (buffer-local-value 'major-mode document))
			 (document-buffer-name
			  (generate-new-buffer-name (concat (unless raw-value-not-empty "Org-noter: ") display-name)))
			 (document-buffer
			  (if (eq document-major-mode 'nov-mode)
			      document
			    (make-indirect-buffer document document-buffer-name t)))

			 (notes-buffer
			  (make-indirect-buffer
			   (or (buffer-base-buffer) (current-buffer))
			   (generate-new-buffer-name (concat "Notes of " display-name)) t))

			 (session
			  (make-org-noter--session
			   :id (org-noter--get-new-id)
			   :display-name display-name
			   :frame
			   (if (or org-noter-always-create-frame
				   (catch 'has-session
				     (dolist (test-session org-noter--sessions)
				       (when (eq (org-noter--session-frame test-session) (selected-frame))
					 (throw 'has-session t)))))
			       (make-frame `((name . ,frame-name) (fullscreen . maximized)))
			     (set-frame-parameter nil 'name frame-name)
			     (selected-frame))
			   :doc-mode document-major-mode
			   :property-text document-property-value
			   :notes-file-path notes-file-path
			   :doc-buffer document-buffer
			   :notes-buffer notes-buffer
			   :level (org-element-property :level ast)
			   :window-behavior (org-noter--property-or-default notes-window-behavior)
			   :window-location (org-noter--property-or-default notes-window-location)
			   :doc-split-fraction (org-noter--property-or-default doc-split-fraction)
			   :auto-save-last-location (org-noter--property-or-default auto-save-last-location)
			   :hide-other (org-noter--property-or-default hide-other)
			   :closest-tipping-point (org-noter--property-or-default closest-tipping-point)
			   :modified-tick -1))

			 (target-location org-noter--start-location-override)
			 (starting-point (point)))

		    (add-hook 'delete-frame-functions 'org-noter--handle-delete-frame)
		    (push session org-noter--sessions)

		    (with-current-buffer document-buffer
		      (cond
		       ;; NOTE(nox): PDF Tools
		       ((eq document-major-mode 'pdf-view-mode)
			(setq buffer-file-name document-path)
			(pdf-view-mode)
			(add-hook 'pdf-view-after-change-page-hook 'org-noter--doc-location-change-handler nil t))

		       ;; NOTE(nox): DocView
		       ((eq document-major-mode 'doc-view-mode)
			(setq buffer-file-name document-path)
			(doc-view-mode)
			(advice-add 'doc-view-goto-page :after 'org-noter--location-change-advice))

		       ;; NOTE(nox): Nov.el
		       ((eq document-major-mode 'nov-mode)
			(rename-buffer document-buffer-name)
			(advice-add 'nov-render-document :after 'org-noter--nov-scroll-handler)
			(add-hook 'window-scroll-functions 'org-noter--nov-scroll-handler nil t))

		       (t (error "This document handler is not supported :/")))

		      (org-noter-doc-mode 1)
		      (setq org-noter--session session)
		      (add-hook 'kill-buffer-hook 'org-noter--handle-kill-buffer nil t))

		    (with-current-buffer notes-buffer
		      (org-noter-notes-mode 1)
		      ;; NOTE(nox): This is needed because a session created in an indirect buffer would use the point of
		      ;; the base buffer (as this buffer is indirect to the base!)
		      (goto-char starting-point)
		      (setq buffer-file-name notes-file-path
			    org-noter--session session
			    (el-patch-remove fringe-indicator-alist '((truncation . nil)))
			    ;; fringe-indicator-alist '((truncation . nil))
			    )
		      (add-hook 'kill-buffer-hook 'org-noter--handle-kill-buffer nil t)
		      (add-hook 'window-scroll-functions 'org-noter--set-notes-scroll nil t)
		      (org-noter--set-text-properties (org-noter--parse-root (vector notes-buffer document-property-value))
						      (org-noter--session-id session))
		      (unless target-location
			(setq target-location (org-noter--location-property (org-noter--get-containing-heading t)))))

		    (org-noter--setup-windows session)

		    ;; NOTE(nox): This timer is for preventing reflowing too soon.
		    (run-with-idle-timer
		     0.05 nil
		     (lambda ()
		       (with-current-buffer document-buffer
			 (let ((org-noter--inhibit-location-change-handler t))
			   (when target-location (org-noter--doc-goto-location target-location)))
			 (org-noter--doc-location-change-handler)))))))
;; -----------------------------------------------------------------------------

(define-key org-noter-doc-mode-map (kbd "j") 'pdf-view-next-line-or-next-page)
(define-key org-noter-doc-mode-map (kbd "k") 'pdf-view-previous-line-or-previous-page)

;;; Default function in org-noter.el
;; (defun org-noter--set-notes-scroll (window &rest ignored)
;;   (when window
;;     (with-selected-window window
;;       (org-noter--with-valid-session
;;        (let* ((level (org-noter--session-level session))
;;               (goal (* (1- level) 2))
;;               (current-scroll (window-hscroll)))
;;          (when (and (bound-and-true-p org-indent-mode) (< current-scroll goal))
;;            (scroll-right current-scroll)
;;            (scroll-left goal t)))))))



;; ========================================
;; ============= HTML EXPORT ==============
;; ========================================

(setq org-html-postamble nil)
;; (setq html-validation-link nil)



;; ========================================
;; ================ AUCTEX ================
;; ========================================

;; Enable LaTeX modes for Orgmode
(add-hook 'LaTeX-mode-hook 'turn-on-reftex)

(eval-after-load "org"
  '(require 'ox-beamer nil t)
  )
(require 'ox-latex)

(setq org-latex-logfiles-extensions '("aux" "bcf" "blg" "fdb_latexmk" "fls" "figlist" "idx" "nav" "out" "ptc" "run.xml" "snm" "toc" "vrb" "xdv")
      org-export-async-debug nil)

(setq reftex-plug-into-AUCTeX t
      reftex-default-bibliography '("/home/zaeph/org/bib/monty-python.bib"))
(setq org-ref-bibliography-notes "/home/zaeph/org/bib/notes.org"
      org-ref-default-bibliography '("/home/zaeph/org/bib/monty-python.bib")
      org-ref-pdf-directory "/home/zaeph/org/bib/pdf")

;; TeX view program
(defvar zp/tex-view-program nil)

(defun zp/tex-view-program-set-pdf-tools ()
  (setq TeX-view-program-selection
	'((output-pdf "PDF Tools"))
	TeX-source-correlate-start-server t
	zp/tex-view-program 'pdf-tools)
  (add-hook #'TeX-after-compilation-finished-functions
	    #'TeX-revert-document-buffer))

(defun zp/tex-view-program-set-evince ()
  (setq TeX-view-program-selection
	'(((output-dvi has-no-display-manager)
	   "dvi2tty")
	  ((output-dvi style-pstricks)
	   "dvips and gv")
	  (output-dvi "xdvi")
	  (output-pdf "Evince")
	  (output-html "xdg-open"))
	TeX-source-correlate-start-server 'ask
	zp/tex-view-program 'evince)
  (remove-hook #'TeX-after-compilation-finished-functions
	       #'TeX-revert-document-buffer))

(defun zp/tex-view-program-switch ()
  (interactive)
  (cond ((eq zp/tex-view-program 'pdf-tools)
	 (zp/tex-view-program-set-evince)
	 (message "TeX view program: Evince"))
	((or (eq zp/tex-view-program 'evince)
	     (not (bound-and-true-p zp/tex-view-program)))
	 (zp/tex-view-program-set-pdf-tools)
	 (message "TeX view program: pdf-tools"))))

(zp/tex-view-program-set-pdf-tools)

;; Update PDF buffers after successful LaTeX runs

;; Smart quotes
(setq org-export-default-language "en-gb"
      org-export-with-smart-quotes t)
(add-to-list 'org-export-smart-quotes-alist
             '("en-gb"
               (primary-opening   :utf-8 "‘" :html "&lsquo;" :latex "\\enquote{"  :texinfo "`")
               (primary-closing   :utf-8 "’" :html "&rsquo;" :latex "}"           :texinfo "'")
               (secondary-opening :utf-8 "“" :html "&ldquo;" :latex "\\enquote*{" :texinfo "``")
               (secondary-closing :utf-8 "”" :html "&rdquo;" :latex "}"           :texinfo "''")
               (apostrophe        :utf-8 "’" :html "&rsquo;" :latex "'")))

;; Loaded on file-basis now
;; (add-to-list 'org-latex-packages-alist '("frenchb,british" "babel" t))
(setq org-latex-default-packages-alist '(("" "graphicx" t)
					 ("" "grffile" t)
					 ("" "longtable" nil)
					 ("" "wrapfig" nil)
					 ("" "rotating" nil)
					 ("normalem" "ulem" t)
					 ("" "amsmath" t)
					 ("" "textcomp" t)
					 ("" "amssymb" t)
					 ("" "capt-of" nil)
					 ("" "setspace" nil)
					 ("" "titletoc" nil)
					 ("" "hyperref" nil)
					 ))

;; BibTeX
(setq bibtex-autokey-year-length '4)

;; XeTeX
(defvar zp/org-latex-pdf-process-mode)
(defun zp/toggle-org-latex-pdf-process ()
  "Toggle the number of steps in the XeTeX PDF process."
  (interactive)
  (if (or (not (bound-and-true-p zp/org-latex-pdf-process-mode))
	  (string= zp/org-latex-pdf-process-mode "full"))
      (progn (setq org-latex-pdf-process '("xelatex -shell-escape\
                                                  -interaction nonstopmode\
                                                  -output-directory %o %f")
		   org-export-async-init-file "/home/zaeph/.emacs.d/async/main-short.el"
		   zp/org-latex-pdf-process-mode 'short)
	     (message "XeLaTeX process mode: Short"))
    (progn (setq org-latex-pdf-process '("xelatex -shell-escape\
                                                    -interaction nonstopmode\
                                                    -output-directory %o %f"
					   "biber %b"
					   "xelatex -shell-escape\
                                                    -interaction nonstopmode\
                                                    -output-directory %o %f"
					   "xelatex -shell-escape\
                                                    -interaction nonstopmode\
                                                    -output-directory %o %f")
		 org-export-async-init-file "/home/zaeph/.emacs.d/async/main-full.el"
		 zp/org-latex-pdf-process-mode 'full)
	   (message "XeLaTeX process mode: Full"))))
(zp/toggle-org-latex-pdf-process)

;; latexmk
;; (setq org-latex-pdf-process '("latexmk -xelatex %f"))
;; (setq org-latex-to-pdf-process (list "latexmk -f -pdf %f"))

;; pdfTeX
;; Need to rework the packages I use before I can use pdfTeX
;; Will need tinkering.
;;
;; microtype:
;; #+LATEX_HEADER: \usepackage[activate={true,nocompatibility},final,tracking=true,kerning=true,spacing=true,factor=1100,stretch=10,shrink=10]{microtype}
;;
;; (setq org-latex-pdf-process
;;       '("pdflatex -shell-escape -interaction nonstopmode -output-directory %o %f"
;; 	"biber %b"
;; 	"pdflatex -shell-escape -interaction nonstopmode -output-directory %o %f"
;; 	"pdflatex -shell-escape -interaction nonstopmode -output-directory %o %f"))

;; LuaTeX
;; Not as good as XeTeX, since I can't figure out how to make CJK characters work.
;; To investigate.
;;
;; # LuaTeXJA
;; #+LATEX_HEADER: \usepackage{luatexja-fontspec}
;; #+LATEX_HEADER: \setmainjfont{A-OTF Ryumin Pr5}
;;
;; (setq org-latex-pdf-process
;;       '("lualatex -shell-escape -interaction nonstopmode -output-directory %o %f"
;; 	"biber %b"
;; 	"lualatex -shell-escape -interaction nonstopmode -output-directory %o %f"
;; 	"lualatex -shell-escape -interaction nonstopmode -output-directory %o %f"))

;; KOMA
(add-to-list 'org-latex-classes
          '("koma-article"
             "\\documentclass{scrartcl}"
             ("\\section{%s}" . "\\section*{%s}")
             ("\\subsection{%s}" . "\\subsection*{%s}")
             ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
             ("\\paragraph{%s}" . "\\paragraph*{%s}")
             ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

;; Minted
(setq org-latex-listings 'minted)
(setq org-src-preserve-indentation t)



;; ========================================
;; ================ SOUNDS ================
;; ========================================

;; Might have to simplify the code one day. Lots of repeat.

;; Windows legacy
;; (defun org-timer-done-sound ()
;;   (start-process-shell-command "play-sound" nil "sounder /id timer-sound /unique ../.emacs.d/sfx/timer.wav"))
;; (setq org-timer-done-hook 'org-timer-done-sound)

;; Max volume is 65536

;; (defun org-timer-done-sound ()
;;   (start-process-shell-command "play-sound" nil "foobar"))
;; (setq org-timer-done-hook 'org-timer-done-sound)

(defun zp/play-sound-clock-in ()
  (start-process-shell-command "play-sound" nil "notification-sound-org clock-in"))
(add-hook 'org-clock-in-prepare-hook 'zp/play-sound-clock-in)

(defun zp/play-sound-clock-out ()
  (start-process-shell-command "play-sound" nil "notification-sound-org clock-out"))  
(add-hook 'org-clock-out-hook 'zp/play-sound-clock-out)

;;; Extra sounds

(defun zp/play-sound-reward ()
  (when (string-equal org-state "DONE")
    ;; (org-clock-out-if-current)		;Default value
    (start-process-shell-command "play-sound" nil "notification-sound-org done")))
(add-hook 'org-after-todo-state-change-hook 'zp/play-sound-reward)

(defun zp/play-sound-start-capture ()
  (start-process-shell-command "play-sound" nil "notification-sound-org open"))
(add-hook 'org-capture-mode-hook 'zp/play-sound-start-capture)

(defun zp/play-sound-after-capture ()
  (start-process-shell-command "play-sound" nil "notification-sound-org close"))
(add-hook 'org-capture-after-finalize-hook 'zp/play-sound-after-capture)

(defun zp/play-sound-after-refile ()
  (start-process-shell-command "play-sound" nil "notification-sound-org move"))
(add-hook 'org-after-refile-insert-hook 'zp/play-sound-after-refile)

(defun zp/play-sound-turn-page ()
  (start-process-shell-command "play-sound" nil "notification-sound-org page"))



;; ========================================
;; ================ HELM ==================
;; ========================================


(helm-mode 1)

;; Disable helm-mode for given functions
;; Used to be necessary, but now it works just fine
;; (add-to-list 'helm-completing-read-handlers-alist '(org-set-property))



;; ========================================
;; ============= HELM BIBTEX ==============
;; ========================================

(require 'helm-bibtex)



;; ------------------------------------------------------------------------------
;; helm-bibtex-select-bib

(defvar zp/bibtex-completion-bib-data-alist nil
  "Alist of the bibliography files and their labels.")

(defvar zp/bibtex-completion-bib-data nil
  "Processed alist of the bibliography files and their labels,
  including an entry with all of them.")

(defun zp/bibtex-completion-bib-data-format ()
  (interactive)
  (setq zp/bibtex-completion-bib-data zp/bibtex-completion-bib-data-alist)
  (map-put zp/bibtex-completion-bib-data
	   "All entries" (list (mapcar 'cdr zp/bibtex-completion-bib-data))))

(defun zp/bibtex-select-bib-init ()
  (zp/bibtex-completion-bib-data-format)
  (setq bibtex-completion-bibliography
	(cdr (assoc "All entries" zp/bibtex-completion-bib-data))))

(defun zp/bibtex-select-bib-select (candidate)
  (setq bibtex-completion-bibliography candidate))

(defun zp/bibtex-select-bib-select-open (candidate)
  (setq bibtex-completion-bibliography candidate)
  (helm-bibtex))

(setq zp/bibtex-completion-select-bib-actions
      '(("Open bibliography" . zp/bibtex-select-bib-select-open)
	("Select bibliography" . zp/bibtex-select-bib-select)))

(setq zp/helm-source-bibtex-select-bib
      '((name . "*HELM Bibtex - Bibliography selection*")
        (candidates . zp/bibtex-completion-bib-data)
        (action . zp/bibtex-completion-select-bib-actions)))

(defun helm-bibtex-select-bib (&optional arg)
  (interactive "p")
  (if (eq arg 4)
      (zp/bibtex-select-bib-init))
  (helm :sources '(zp/helm-source-bibtex-select-bib)))
;; ------------------------------------------------------------------------------



(setq zp/bibtex-completion-bib-data-alist
      '(("Monty Python" . "/home/zaeph/org/bib/monty-python.bib")
	;; ("Monty Python - Extra" . "/home/zaeph/org/bib/monty-python-extra.bib")
	("FromSoftware" . "/home/zaeph/org/bib/fromsoftware.bib")))

(zp/bibtex-select-bib-init)

;; Autokey generation
(setq bibtex-align-at-equal-sign t
      bibtex-autokey-name-year-separator ""
      bibtex-autokey-year-title-separator ""
      bibtex-autokey-year-length 4
      bibtex-autokey-titleword-first-ignore '("the" "a" "if" "and" "an")
      bibtex-autokey-titleword-length 20
      bibtex-autokey-titlewords-stretch 0
      bibtex-autokey-titlewords 0)

(setq bibtex-completion-pdf-field "file")

(setq bibtex-completion-pdf-symbol "P"
      bibtex-completion-notes-symbol "N")

;; Additional fields
(setq bibtex-user-optional-fields '(("subtitle" "Subtitle")
				    ("booksubtitle" "Book subtitle")
				    ("langid" "Language to use with BibLaTeX")
				    ("library" "Library where the resource is held")
				    ("shelf" "Shelf number at the library")
				    ("annote" "Personal annotation (ignored)")
				    ("keywords" "Personal keywords")
				    ("tags" "Personal tags")
				    ("file" "Path to file")
				    ("url" "URL to reference"))

      helm-bibtex-additional-search-fields '(subtitle booksubtitle keywords tags library))

;; Define which citation function to use on a buffer basis
(setq bibtex-completion-format-citation-functions
      '((org-mode      . bibtex-completion-format-citation-cite)
	(latex-mode    . bibtex-completion-format-citation-cite)
	(bibtex-mode   . bibtex-completion-format-citation-cite)
	(markdown-mode . bibtex-completion-format-citation-pandoc-citeproc)
	(default       . bibtex-completion-format-citation-default)))

;; PDF open function
(setq bibtex-completion-pdf-open-function 'helm-open-file-with-default-tool)



;; Custom action: Select current document

;; (defvar zp/current-document)
;; (defun zp/select-current-document ()
;;   (interactive)
;;   (setq zp/current-document
;; 	(read-string
;; 	 (concat "Current document(s)"
;; 		 (if (bound-and-true-p zp/current-document)
;; 		     (concat " [" zp/current-document "]"))
;; 		 ": "))))

;; (defun zp/bibtex-completion-select-current-document (keys)
;;   (setq zp/current-document (s-join ", " keys)))
;; (helm-bibtex-helmify-action zp/bibtex-completion-select-current-document helm-bibtex-select-current-document)



(defvar zp/bibtex-completion-key-last nil
  "Last inserted keys.")

(defun zp/bibtex-completion-format-citation-default (keys)
  "Default formatter for keys, separates multiple keys with
commas."
  (s-join "," keys))

(defun zp/bibtex-completion-format-citation-comma-space (keys)
  "Formatter for keys, separates multiple keys with
commas and space."
  (s-join ", " keys))

(defun zp/bibtex-completion-insert-key (keys)
  "Insert BibTeX key at point."
  (let ((current-keys (zp/bibtex-completion-format-citation-default keys)))
    (insert current-keys)
    (setq zp/bibtex-completion-key-last keys)))

(defun zp/bibtex-completion-insert-key-last ()
  (interactive)
  (let ((last-keys (zp/bibtex-completion-format-citation-default
		    zp/bibtex-completion-key-last)))
    (if (bound-and-true-p last-keys)
	(insert last-keys)
      (zp/helm-bibtex-solo-action-insert-key))))

(defun zp/bibtex-completion-message-key-last ()
  (interactive)
  (let ((keys (zp/bibtex-completion-format-citation-comma-space
	       zp/bibtex-completion-key-last)))
    (if (bound-and-true-p keys)
	(message (concat "Last key(s) used: " keys "."))
      (message "No previous key used."))))

;; Add to helm
(helm-bibtex-helmify-action zp/bibtex-completion-insert-key zp/helm-bibtex-insert-key)
(helm-delete-action-from-source "Insert BibTeX key" helm-source-bibtex)
(helm-add-action-to-source "Insert BibTeX key" 'zp/helm-bibtex-insert-key helm-source-bibtex 4)

;; Define solo action: Insert BibTeX key
(setq zp/helm-source-bibtex-insert-key '(("Insert BibTeX key" . zp/helm-bibtex-insert-key)))
(defun zp/helm-bibtex-solo-action-insert-key ()
  (interactive)
  (let ((inhibit-message t)
	(previous-actions (helm-attr 'action helm-source-bibtex))
	(new-action zp/helm-source-bibtex-insert-key))
    (helm-attrset 'action new-action helm-source-bibtex)
    (helm-bibtex)
    ;; Wrapping with (progn (foo) nil) suppress the output
    (progn (helm-attrset 'action previous-actions helm-source-bibtex) nil)))





;; OLD CONFIGURATION
;; DISABLED
;; Uncomment entire block to resume function

;; (setq bibtex-completion-pdf-symbol "P"
;;       bibtex-completion-notes-symbol "N")

;; ;; (setq bibtex-completion-bibliography '("/home/zaeph/org/uni/phonology/refs.bib"
;; ;; 				       "/home/zaeph/org/uni/civ/refs.bib"))

;; ;; Obsolete with `helm-bibtex-switch'
;; ;; (setq helm-bibtex-pdf-open-function 'org-open-file
;; ;;       helm-bibtex-full-frame nil)

;; ;; Autokey generation
;; (setq bibtex-align-at-equal-sign t
;;       bibtex-autokey-name-year-separator ""
;;       bibtex-autokey-year-title-separator ""
;;       bibtex-autokey-titleword-first-ignore '("the" "a" "if" "and" "an")
;;       bibtex-autokey-titleword-length 20
;;       bibtex-autokey-titlewords-stretch 0
;;       bibtex-autokey-titlewords 1)

;; ;; Additional fields
;; (setq helm-bibtex-additional-search-fields '(keywords tags library)
;;       bibtex-user-optional-fields '(("langid" "Language to use with BibLaTeX")
;; 				    ("library" "Library where the resource is held")
;; 				    ("shelf" "Shelf number at the library")
;; 				    ("annote" "Personal annotation (ignored)")
;; 				    ("keywords" "Personal keywords")
;; 				    ("tags" "Personal tags")))

;; ;; Define which citation function to use on a buffer basis
;; (setq bibtex-completion-format-citation-functions
;;       '((org-mode      . bibtex-completion-format-citation-)
;; 	(latex-mode    . bibtex-completion-format-citation-cite)
;; 	(bibtex-mode   . bibtex-completion-format-citation-cite)
;; 	(markdown-mode . bibtex-completion-format-citation-pandoc-citeproc)
;; 	(default       . bibtex-completion-format-citation-default)))

;; ;; Helm source
;; (defun bibtex-completion-insert-org-link (_)
;;   "Inserts an org-link to the marked entries."
;;   (let ((keys (helm-marked-candidates :with-wildcard t))
;;         (format-function 'bibtex-completion-format-citation-org-link-to-PDF))
;;     (with-helm-current-buffer
;;       (insert
;;        (funcall format-function keys)))))

;; (defun bibtex-completion-open-pdf-with-org-open-file (candidates)
;;   "Open the PDFs associated with the marked entries using the
;; function specified in `bibtex-completion-pdf-open-function'.  All paths
;; in `bibtex-completion-library-path' are searched.  If there are several
;; matching PDFs for an entry, the first is opened."
;;   (--if-let
;;       (-flatten
;;        (-map 'bibtex-completion-find-pdf
;;              (if (listp candidates) candidates (list candidates))))
;;       (-each it 'org-open-file)
;;     (message "No PDF(s) found.")))

;; (defun bibtex-completion-open-pdf-with-find-file (candidates)
;;   "Open the PDFs associated with the marked entries using the
;; function specified in `bibtex-completion-pdf-open-function'.  All paths
;; in `bibtex-completion-library-path' are searched.  If there are several
;; matching PDFs for an entry, the first is opened."
;;   (--if-let
;;       (-flatten
;;        (-map 'bibtex-completion-find-pdf
;;              (if (listp candidates) candidates (list candidates))))
;;       (-each it 'find-file)
;;     (message "No PDF(s) found.")))

;; (setq helm-source-bibtex
;;   '((name                                      . "BibTeX entries")
;;     (init                                      . bibtex-completion-init)
;;     (candidates                                . bibtex-completion-candidates)
;;     (filtered-candidate-transformer            . helm-bibtex-candidates-formatter) ;helm-bibtex-candidates-formatter doesn't seem to work for some reason
;;     (action . (("Open PDF file externally (if present)" . bibtex-completion-open-pdf-with-org-open-file)
;; 	       ("Insert citation"                       . bibtex-completion-insert-citation)
;; 	       ("Insert org-link to PDF"                . bibtex-completion-insert-org-link)
;;                ("Edit notes"                            . bibtex-completion-edit-notes)
;;                ("Show entry"                            . bibtex-completion-show-entry)
;;                ("Insert BibTeX key"                     . bibtex-completion-insert-key)
;;                ("Insert BibTeX entry"                   . bibtex-completion-insert-bibtex)
;; 	       ("Open PDF file internally (if present)" . bibtex-completion-open-pdf-with-find-file)
;; 	       ("Open URL or DOI in browser"            . bibtex-completion-open-url-or-doi)
;; 	       ("Insert reference"                      . bibtex-completion-insert-reference)
;;                ("Attach PDF to email"                   . bibtex-completion-add-PDF-attachment)))))

;; ;; bib files
;; (setq bib-data '(("All" . ("/home/zaeph/org/old/uni/phonology/refs.bib"
;; 			   "/home/zaeph/org/old/uni/civilisation/refs.bib"
;; 			   "/home/zaeph/org/old/uni/physics/refs.bib"))
;; 		 ("Phonology" . "/home/zaeph/org/old/uni/phonology/refs.bib")
;; 		 ("Civilisation" . "/home/zaeph/org/old/uni/civilisation/refs.bib")
;; 		 ("Physics" . "/home/zaeph/org/old/uni/physics/refs.bib")
;; 		 ("Labour" . "/home/zaeph/org/projects/university/courses/civilisation/refs.bib")))

;; ;; Folders where the PDFs and notes are
;; (setq bibtex-completion-notes-path "/home/zaeph/org/refs/notes.org"
;;       bibtex-completion-library-path '("/home/zaeph/../pdfs/phonology"
;; 				       "/home/zaeph/../pdfs/civilisation"
;; 				       "k:/pdfs/phonology"
;; 				       "k:/pdfs/civilisation"))

;; ;; Init on all entries
;; (defun bibtex-completion-default ()
;;   "Sets the default bibliography and buffer-name to be used by helm-bibtex."
;;   (setq bibtex-completion-bibliography (cdr (assoc "All" bib-data))
;; 	bibtex-completion-buffer "*Helm BibTeX* All"))

;; (bibtex-completion-default)

;; (defun bibtex-completion-open (candidate &optional arg)
;;   (bibtex-completion-switch arg
;; 		      :bib (cdr (assoc candidate bib-data))
;; 		      :buffer (concat "*Helm BibTeX* " (car (assoc candidate bib-data)))))
;; (defun bibtex-completion-open-full-frame (candidate &optional arg)
;;   (bibtex-completion-switch arg
;; 		      :bib (cdr (assoc candidate bib-data))
;; 		      :buffer (concat "*Helm BibTeX* " (car (assoc candidate bib-data)))
;; 		      :full-frame t))

;; (cl-defun bibtex-completion-switch (&optional arg &key bib buffer (full-frame nil) (candidate-number-limit 500))
;;   "Search BibTeX entries."
;;   (interactive)
;;   (setq bibtex-completion-bibliography bib)
;;   (setq bibtex-completion-buffer buffer)
;;   (when (eq arg 4)
;;     (setq bibtex-completion-bibliography-hash ""))
;;   (when (eq arg 16)
;;     (bibtex-completion-default))
;;   (helm :sources '(helm-source-bibtex helm-source-fallback-options)
;; 	:full-frame full-frame
;; 	:buffer bibtex-completion-buffer
;; 	:candidate-number-limit candidate-number-limit))

;; (setq bibtex-completion-sources
;;       `((name . "*Helm BibTeX* Sources")
;;         (candidates . ,(mapcar 'car bib-data))
;;         (action
;; 	 ("Load bibliography" . bibtex-completion-open)
;; 	 ("Load bibliography (full window)" . bibtex-completion-open-full-frame)
;; 	 ("Reload bibliography"))))

;; (global-set-key (kbd "C-c b") (lambda (&optional arg)
;; 				(interactive "p")
;; 				(bibtex-completion-switch arg
;; 						    :bib bibtex-completion-bibliography
;; 						    :buffer bibtex-completion-buffer
;; 						    :full-frame nil)))
;; ;; (global-set-key (kbd "C-c B") (lambda (&optional arg)
;; ;; 				(interactive "p")
;; ;; 				(bibtex-completion-switch arg
;; ;; 						    :bib bibtex-completion-bibliography
;; ;; 						    :buffer bibtex-completion-buffer
;; ;; 						    :full-frame t)))
;; (global-set-key (kbd "C-c B") (lambda ()
;; 				(interactive)
;; 				(helm :sources bibtex-completion-sources)))



;; ========================================
;; ============ EXPERIMENTAL ==============
;; ========================================

;; (require 'notifications)
;; (notifications-notify :title "Achtung!"
;;                       :body (format "You have an appointment in %d minutes" 10)
;;                       :app-name "Emacs: Org"
;; 		      :urgency "critical"
;;                       :sound-name "/home/zaeph/SFX/Misc/rimshot.mp3")



;; ========================================
;; ============== EXTERNAL ================
;; ========================================

;;; Obsolete, but useful for creating toggles
;; (defun clean-mode ()
;;   "Removes scroll bars.
;; Generates flicker on certain elements (e.g. linum)."
;;   (interactive)
;;   (if (bound-and-true-p scroll-bar-mode)
;;       (scroll-bar-mode -1)
;;     (scroll-bar-mode 1)))

;; (defun org-mode-enhanced-reading ()
;;   "Activate both org-indent-mode and visual-line-mode."
;;   (interactive)
;;   (if (bound-and-true-p org-indent-mode)
;;       (progn
;;         (org-indent-mode -1))
;;     (progn
;;       (org-indent-mode t))))



;;; Not sure what it does anymore... ?
;; (defun push-mark-no-activate ()
;;   "Pushes `point' to `mark-ring' and does not activate the region
;;    Equivalent to \\[set-mark-command] when \\[transient-mark-mode] is disabled"
;;   (interactive)
;;   (push-mark (point) t nil)
;;   (message "Pushed mark to ring"))

;; (global-set-key (kbd "C-`") 'push-mark-no-activate)

;; (defun jump-to-mark ()
;;   "Jumps to the local mark, respecting the `mark-ring' order.
;;   This is the same as using \\[set-mark-command] with the prefix argument."
;;   (interactive)
;;   (set-mark-command 1))
;; (global-set-key (kbd "M-`") 'jump-to-mark)



;; Increment/Decrement integer at point
(require 'thingatpt)

(defun thing-at-point-goto-end-of-integer ()
  "Go to end of integer at point."
  (let ((inhibit-changing-match-data t))
    ;; Skip over optional sign
    (when (looking-at "[+-]")
      (forward-char 1))
    ;; Skip over digits
    (skip-chars-forward "[[:digit:]]")
    ;; Check for at least one digit
    (unless (looking-back "[[:digit:]]")
      (error "No integer here"))))
(put 'integer 'beginning-op 'thing-at-point-goto-end-of-integer)

(defun thing-at-point-goto-beginning-of-integer ()
  "Go to end of integer at point."
  (let ((inhibit-changing-match-data t))
    ;; Skip backward over digits
    (skip-chars-backward "[[:digit:]]")
    ;; Check for digits and optional sign
    (unless (looking-at "[+-]?[[:digit:]]")
      (error "No integer here"))
    ;; Skip backward over optional sign
    (when (looking-back "[+-]")
        (backward-char 1))))
(put 'integer 'beginning-op 'thing-at-point-goto-beginning-of-integer)

(defun thing-at-point-bounds-of-integer-at-point ()
  "Get boundaries of integer at point."
  (save-excursion
    (let (beg end)
      (thing-at-point-goto-beginning-of-integer)
      (setq beg (point))
      (thing-at-point-goto-end-of-integer)
      (setq end (point))
      (cons beg end))))
(put 'integer 'bounds-of-thing-at-point 'thing-at-point-bounds-of-integer-at-point)

(defun thing-at-point-integer-at-point ()
  "Get integer at point."
  (let ((bounds (bounds-of-thing-at-point 'integer)))
    (string-to-number (buffer-substring (car bounds) (cdr bounds)))))
(put 'integer 'thing-at-point 'thing-at-point-integer-at-point)

(defun increment-integer-at-point (&optional inc)
  "Increment integer at point by one.

With numeric prefix arg INC, increment the integer by INC amount."
  (interactive "p")
  (let ((inc (or inc 1))
        (n (thing-at-point 'integer))
        (bounds (bounds-of-thing-at-point 'integer)))
    (delete-region (car bounds) (cdr bounds))
    (insert (int-to-string (+ n inc)))))

(defun decrement-integer-at-point (&optional dec)
  "Decrement integer at point by one.

With numeric prefix arg DEC, decrement the integer by DEC amount."
  (interactive "p")
  (increment-integer-at-point (- (or dec 1))))(require 'thingatpt)

(defun thing-at-point-goto-end-of-integer ()
  "Go to end of integer at point."
  (let ((inhibit-changing-match-data t))
    ;; Skip over optional sign
    (when (looking-at "[+-]")
      (forward-char 1))
    ;; Skip over digits
    (skip-chars-forward "[[:digit:]]")
    ;; Check for at least one digit
    (unless (looking-back "[[:digit:]]")
      (error "No integer here"))))
(put 'integer 'beginning-op 'thing-at-point-goto-end-of-integer)

(defun thing-at-point-goto-beginning-of-integer ()
  "Go to end of integer at point."
  (let ((inhibit-changing-match-data t))
    ;; Skip backward over digits
    (skip-chars-backward "[[:digit:]]")
    ;; Check for digits and optional sign
    (unless (looking-at "[+-]?[[:digit:]]")
      (error "No integer here"))
    ;; Skip backward over optional sign
    (when (looking-back "[+-]")
        (backward-char 1))))
(put 'integer 'beginning-op 'thing-at-point-goto-beginning-of-integer)

(defun thing-at-point-bounds-of-integer-at-point ()
  "Get boundaries of integer at point."
  (save-excursion
    (let (beg end)
      (thing-at-point-goto-beginning-of-integer)
      (setq beg (point))
      (thing-at-point-goto-end-of-integer)
      (setq end (point))
      (cons beg end))))
(put 'integer 'bounds-of-thing-at-point 'thing-at-point-bounds-of-integer-at-point)

(defun thing-at-point-integer-at-point ()
  "Get integer at point."
  (let ((bounds (bounds-of-thing-at-point 'integer)))
    (string-to-number (buffer-substring (car bounds) (cdr bounds)))))
(put 'integer 'thing-at-point 'thing-at-point-integer-at-point)

(defun increment-integer-at-point (&optional inc)
  "Increment integer at point by one.

With numeric prefix arg INC, increment the integer by INC amount."
  (interactive "p")
  (let ((inc (or inc 1))
        (n (thing-at-point 'integer))
        (bounds (bounds-of-thing-at-point 'integer)))
    (delete-region (car bounds) (cdr bounds))
    (insert (int-to-string (+ n inc)))))

(defun decrement-integer-at-point (&optional dec)
  "Decrement integer at point by one.

With numeric prefix arg DEC, decrement the integer by DEC amount."
  (interactive "p")
  (increment-integer-at-point (- (or dec 1))))



(defun window-toggle-split-direction ()
  "Switch window split from horizontally to vertically, or vice versa.

i.e. change right window to bottom, or change bottom window to right."
  (interactive)
  (require 'windmove)
  (let ((done))
    (dolist (dirs '((right . down) (down . right)))
      (unless done
        (let* ((win (selected-window))
               (nextdir (car dirs))
               (neighbour-dir (cdr dirs))
               (next-win (windmove-find-other-window nextdir win))
               (neighbour1 (windmove-find-other-window neighbour-dir win))
               (neighbour2 (if next-win (with-selected-window next-win
                                          (windmove-find-other-window neighbour-dir next-win)))))
          ;;(message "win: %s\nnext-win: %s\nneighbour1: %s\nneighbour2:%s" win next-win neighbour1 neighbour2)
          (setq done (and (eq neighbour1 neighbour2)
                          (not (eq (minibuffer-window) next-win))))
          (if done
              (let* ((other-buf (window-buffer next-win)))
                (delete-window next-win)
                (if (eq nextdir 'right)
                    (split-window-vertically)
                  (split-window-horizontally))
                (set-window-buffer (windmove-find-other-window neighbour-dir) other-buf))))))))




;; (defun zp/switch-to-agenda ()
;;   (interactive)
;;   (if (string-match ".*Org Agenda.*" (buffer-name))
;;       (mode-line-other-buffer)
;;     (switch-to-buffer "*Org Agenda(n)*")))

(defun zp/create-agenda-view (arg)
  (interactive "P")
  (if (get-buffer "*Org Agenda(n)*")
      (switch-to-buffer "*Org Agenda(n)*")
    (org-agenda arg "n"))
  (delete-other-windows)
  (split-window-right)
  (if (get-buffer "*Org Agenda(N)*")
      (switch-to-buffer "*Org Agenda(N)*")
    (org-agenda arg "N"))
  (other-window 1)
  (balance-windows))

(defun zp/switch-to-agenda (arg)
  "Toggles a custom org-agenda context, or creates it if it doesn’t
  exist.

The layout of the org-agenda context is stored as a frame
parameter, which implies that each frame can have its own
independent org-agenda context.

With a ‘C-u’ prefix argument, forces the re-creation of the
org-agenda context."

  (interactive "P")
  (let* ((current-config (current-window-configuration))
	 (current-frame (window-configuration-frame current-config)))

    (cond ((and
	    (frame-parameter current-frame
			     'zp/org-agenda-session-p)
	    (not arg))
	   (set-frame-parameter current-frame
				'zp/org-agenda-window-config
				current-config)
	   (set-window-configuration
	    (frame-parameter current-frame
			     'zp/org-agenda-window-config-before))
	   (set-frame-parameter current-frame
				'zp/org-agenda-session-p nil))

	  (t
	   (set-frame-parameter current-frame
				'zp/org-agenda-window-config-before
				current-config)
	   (if (or arg
		   (not (frame-parameter current-frame
					 'zp/org-agenda-window-config)))
	       (zp/create-agenda-view arg)
	     (set-window-configuration
	      (frame-parameter current-frame
			       'zp/org-agenda-window-config)))
	   (set-frame-parameter current-frame
				'zp/org-agenda-session-p t)))))



(defun zp/switch-to-chronos (arg)
  (interactive "P")
  (if (string-match "*chronos*" (buffer-name))
      (mode-line-other-buffer)
    (if (or (eq (get-buffer "*chronos*") nil) (not (eq arg nil)))
	;; (message "There are no timer running.")
	(call-interactively 'helm-chronos-add-timer)
      (switch-to-buffer "*chronos*"))))

;; (defun zp/switch-to-magit (arg)
;;   (interactive "P")
;;   (if (string-match "magit: .*" (buffer-name))
;;       (magit-mode-bury-buffer arg)
;;     (magit-status arg)))

(defun zp/switch-to-mu4e ()
  (interactive)
  (if (string-match "*mu4e-.*" (buffer-name))
      (progn
	(mu4e-quit)
	(set-window-configuration zp/mu4e-before-config))
    (if (eq (get-buffer "*mu4e-main*") nil)
	(progn
	  (setq zp/mu4e-before-config (current-window-configuration))
	  (mu4e)))))

(advice-add #'mu4e-quit :after (lambda ()
				 (mu4e-update-mail-and-index t)))

(defun zp/mu4e-view-message-with-message-id-save-window-config-before (old-function &rest arguments)
  (interactive)
  (setq zp/mu4e-before-config (current-window-configuration))
  (apply old-function arguments))

(advice-add #'mu4e-view-message-with-message-id :around #'zp/mu4e-view-message-with-message-id-save-window-config-before)

(defun zp/echo-buffer-name ()
  (interactive)
  (message (concat "Current buffer: " (replace-regexp-in-string "%" "%%" (buffer-name)))))

(defun zp/echo-clock-string ()
  "Echo the tasks being currently clocked in the minibuffer,
along with effort estimates and total time."
  (interactive)
  (if (org-clocking-p)
      (let ((header "Current clock")
	    (clocked-time (org-clock-get-clocked-time))
	    (org-clock-heading-formatted (replace-regexp-in-string "%" "%%"org-clock-heading)))
	(if org-clock-effort
	    (let* ((effort-in-minutes (org-duration-to-minutes org-clock-effort))
		   (work-done-str
		    (propertize (org-duration-from-minutes clocked-time)
				'face
				(if (and org-clock-task-overrun
					 (not org-clock-task-overrun-text))
				    'org-mode-line-clock-overrun
				  'org-meta-line)))
		   (effort-str (org-duration-from-minutes effort-in-minutes)))
	      (message (concat
			header ": "
			(format (propertize "[%s/%s] (%s)" 'face 'org-meta-line)
				work-done-str effort-str org-clock-heading-formatted))))
	  (message (concat
		    header ": "
		    (format (propertize "[%s] (%s)" 'face 'org-meta-line)
			   (org-duration-from-minutes clocked-time)
			   org-clock-heading-formatted)))))
    (error "Not currently clocking any task.")))



;; Tag skip
;; Not needed at the moment, but might come in handy when trying to
;; write a single skip-function for my org-agenda blocks.
;; (defun zp/org-agenda-skip-tag (tag &optional others)
;;   "Skip all entries that correspond to TAG.

;; If OTHERS is true, skip all entries that do not correspond to TAG."
;;   (let ((next-headline (save-excursion (or (outline-next-heading) (point-max))))
;;         (current-headline (or (and (org-at-heading-p)
;;                                    (point))
;;                               (save-excursion (org-back-to-heading)))))
;;     (if others
;;         (if (not (member tag (org-get-tags-at current-headline)))
;;             next-headline
;;           nil)
;;       (if (member tag (org-get-tags-at current-headline))
;;           next-headline
;;         nil))))



;; Norang
;; To study in depth to master org-agenda

(setq org-stuck-projects (quote ("" nil nil "")))

(defun bh/is-project-p ()
  "Any task with a todo keyword subtask"
  (save-restriction
    (widen)
    (let ((has-subtask)
          (subtree-end (save-excursion (org-end-of-subtree t)))
          (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
      (save-excursion
        (forward-line 1)
        (while (and (not has-subtask)
                    (< (point) subtree-end)
                    (re-search-forward "^\*+ " subtree-end t))
          (when (member (org-get-todo-state) org-todo-keywords-1)
            (setq has-subtask t))))
      (and is-a-task has-subtask))))

(defun bh/is-project-subtree-p ()
  "Any task with a todo keyword that is in a project subtree.
Callers of this function already widen the buffer view."
  (let ((task (save-excursion (org-back-to-heading 'invisible-ok)
                              (point))))
    (save-excursion
      (bh/find-project-task)
      (if (equal (point) task)
          nil
        t))))

(defun bh/is-task-p ()
  "Any task with a todo keyword and no subtask"
  (save-restriction
    (widen)
    (let ((has-subtask)
          (subtree-end (save-excursion (org-end-of-subtree t)))
          (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
      (save-excursion
        (forward-line 1)
        (while (and (not has-subtask)
                    (< (point) subtree-end)
                    (re-search-forward "^\*+ " subtree-end t))
          (when (member (org-get-todo-state) org-todo-keywords-1)
            (setq has-subtask t))))
      (and is-a-task (not has-subtask)))))

(defun bh/is-subproject-p ()
  "Any task which is a subtask of another project"
  (let ((is-subproject)
        (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
    (save-excursion
      (while (and (not is-subproject) (org-up-heading-safe))
        (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
          (setq is-subproject t))))
    (and is-a-task is-subproject)))

(defun bh/list-sublevels-for-projects-indented ()
  "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
  This is normally used by skipping functions where this variable is already local to the agenda."
  (if (marker-buffer org-agenda-restrict-begin)
      (setq org-tags-match-list-sublevels 'indented)
    (setq org-tags-match-list-sublevels nil))
  nil)

(defun bh/list-sublevels-for-projects ()
  "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
  This is normally used by skipping functions where this variable is already local to the agenda."
  (if (marker-buffer org-agenda-restrict-begin)
      (setq org-tags-match-list-sublevels t)
    (setq org-tags-match-list-sublevels nil))
  nil)

(defvar bh/hide-scheduled-and-waiting-next-tasks t)

(defun bh/toggle-next-task-display ()
  (interactive)
  (setq bh/hide-scheduled-and-waiting-next-tasks (not bh/hide-scheduled-and-waiting-next-tasks))
  (when  (equal major-mode 'org-agenda-mode)
    (org-agenda-redo))
  (message "%s WAITING and SCHD NEXT Tasks" (if bh/hide-scheduled-and-waiting-next-tasks "Hide" "Show")))


(defun bh/skip-stuck-projects ()
  "Skip trees that are not stuck projects"
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next ))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
                (unless (member "WAITING" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                nil
              next-headline)) ; a stuck project, has subtasks but no next task
        nil))))

(defun bh/skip-non-stuck-projects ()
  "Skip trees that are not stuck projects"
  ;; (bh/list-sublevels-for-projects-indented)
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next ))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
                (unless (member "WAITING" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                next-headline
              nil)) ; a stuck project, has subtasks but no next task
        next-headline))))

(defun zp/skip-stuck-projects ()
  "Skip trees that are not stuck projects"
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next))
            (save-excursion
              (forward-line 1)
	      (while (and (not has-next)
			  (< (point) subtree-end)
			  (if zp/projects-include-waiting
			      (re-search-forward "^\\*+ \\(NEXT\\|STRT\\) " subtree-end t)
			    (re-search-forward "^\\*+ \\(NEXT\\|STRT\\|WAIT\\) " subtree-end t)))
                (unless (member "standby" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                nil
              next-headline)) ; a stuck project, has subtasks but no next task
        nil))))

(defvar zp/projects-include-waiting nil
  "When t, includes stuck projects with a waiting task in the
agenda.")

(defun zp/skip-non-stuck-projects ()
  "Skip trees that are not stuck projects"
  ;; (bh/list-sublevels-for-projects-indented)
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
		 (is-waiting (string-match-p "WAIT" (org-get-todo-state)))
                 (has-next))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next)
			  (< (point) subtree-end)
			  (if is-waiting
			      (re-search-forward "^\\*+ \\(WAIT\\) " subtree-end t)
			    (re-search-forward "^\\*+ \\(NEXT\\|STRT\\) " subtree-end t)))
                (unless (member "standby" (org-get-tags-at))
		  (setq has-next t))))
            (if has-next
                next-headline
              nil)) ; a stuck project, has subtasks but no next task
        next-headline))))

(defun bh/skip-non-projects ()
  "Skip trees that are not projects"
  ;; (bh/list-sublevels-for-projects-indented)
  (if (save-excursion (bh/skip-non-stuck-projects))
      (save-restriction
        (widen)
        (let ((subtree-end (save-excursion (org-end-of-subtree t))))
          (cond
           ((bh/is-project-p)
            nil)
           ((and (bh/is-project-subtree-p) (not (bh/is-task-p)))
            nil)
           (t
            subtree-end))))
    (save-excursion (org-end-of-subtree t))))

(defun zp/skip-non-projects ()
  "Skip trees that are not projects"
  ;; (bh/list-sublevels-for-projects-indented)
  (if (save-excursion (zp/skip-non-stuck-projects))
      (save-restriction
        (widen)
        (let ((subtree-end (save-excursion (org-end-of-subtree t))))
          (cond
           ((bh/is-project-p)
            nil)
           ((and (bh/is-project-subtree-p) (not (bh/is-task-p)))
            nil)
           (t
            subtree-end))))
    (save-excursion (org-end-of-subtree t))))

(defun zp/skip-non-projects-and-waiting ()
  (or
   (zp/skip-non-projects)
   (if (not zp/projects-include-waiting)
      (org-agenda-skip-entry-if 'todo '("WAIT")))))

(defun bh/skip-non-tasks ()
  "Show non-project tasks.
Skip project and sub-project tasks, habits, and project related tasks."
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (cond
       ((bh/is-task-p)
        nil)
       (t
        next-headline)))))

(defun zp/skip-non-tasks-and-scheduled ()
  (or
   (bh/skip-non-tasks)
   (org-agenda-skip-entry-if 'scheduled)))

(defun bh/skip-project-trees-and-habits ()
  "Skip trees that are projects"
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
       ((org-is-habit-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-projects-and-habits-and-single-tasks ()
  "Skip trees that are projects, tasks that are habits, single non-project tasks"
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (cond
       ((org-is-habit-p)
        next-headline)
       ((and bh/hide-scheduled-and-waiting-next-tasks
             (member "WAITING" (org-get-tags-at)))
        next-headline)
       ((bh/is-project-p)
        next-headline)
       ((and (bh/is-task-p) (not (bh/is-project-subtree-p)))
        next-headline)
       (t
        nil)))))

(defun bh/skip-project-tasks-maybe ()
  "Show tasks related to the current restriction.
When restricted to a project, skip project and sub project tasks, habits, NEXT tasks, and loose tasks.
When not restricted, skip project and sub-project tasks, habits, and project related tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
           (next-headline (save-excursion (or (outline-next-heading) (point-max))))
           (limit-to-project (marker-buffer org-agenda-restrict-begin)))
      (cond
       ((bh/is-project-p)
        next-headline)
       ((org-is-habit-p)
        subtree-end)
       ((and (not limit-to-project)
             (bh/is-project-subtree-p))
        subtree-end)
       ((and limit-to-project
             (bh/is-project-subtree-p)
             (member (org-get-todo-state) (list "NEXT")))
        subtree-end)
       (t
        nil)))))

(defun bh/skip-project-tasks ()
  "Show non-project tasks.
Skip project and sub-project tasks, habits, and project related tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
       ((org-is-habit-p)
        subtree-end)
       ((bh/is-project-subtree-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-non-project-tasks ()
  "Show project tasks.
Skip project and sub-project tasks, habits, and loose non-project tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
           (next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (cond
       ((bh/is-project-p)
        next-headline)
       ((org-is-habit-p)
        subtree-end)
       ((and (bh/is-project-subtree-p)
             (member (org-get-todo-state) (list "NEXT")))
        subtree-end)
       ((not (bh/is-project-subtree-p))
        subtree-end)
       (t
        nil)))))

(defun bh/skip-projects-and-habits ()
  "Skip trees that are projects and tasks that are habits"
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
       ((org-is-habit-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-non-subprojects ()
  "Skip trees that are not projects"
  (let ((next-headline (save-excursion (outline-next-heading))))
    (if (bh/is-subproject-p)
        nil
      next-headline)))

(defun bh/find-project-task ()
  "Move point to the parent (project) task if any"
  (save-restriction
    (widen)
    (let ((parent-task (save-excursion (org-back-to-heading 'invisible-ok) (point))))
      (while (org-up-heading-safe)
        (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
          (setq parent-task (point))))
      (goto-char parent-task)
      parent-task)))



;; 18.2.1 Narrowing to a subtree with bh/org-todo
;; (global-set-key (kbd "<f5>") 'bh/org-todo)

;; (defun bh/org-todo (arg)
;;   (interactive "p")
;;   (if (equal arg 4)
;;       (save-restriction
;;         (bh/narrow-to-org-subtree)
;;         (org-show-todo-tree nil))
;;     (bh/narrow-to-org-subtree)
;;     (org-show-todo-tree nil)))

;; (global-set-key (kbd "<S-f5>") 'bh/widen)

;; (defun bh/widen ()
;;   (interactive)
;;   (if (equal major-mode 'org-agenda-mode)
;;       (progn
;;         (org-agenda-remove-restriction-lock)
;;         (when org-agenda-sticky
;;           (org-agenda-redo)))
;;     (widen)))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defkey org-agenda-mode-map "W" (lambda () (interactive) (setq bh/hide-scheduled-and-waiting-next-tasks t) (bh/widen))))
;;           'append)

;; (defun bh/restrict-to-file-or-follow (arg)
;;   "Set agenda restriction to 'file or with argument invoke follow mode.
;; I don't use follow mode very often but I restrict to file all the time
;; so change the default 'F' binding in the agenda to allow both"
;;   (interactive "p")
;;   (if (equal arg 4)
;;       (org-agenda-follow-mode)
;;     (widen)
;;     (bh/set-agenda-restriction-lock 4)
;;     (org-agenda-redo)
;;     (beginning-of-buffer)))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defnkey org-agenda-mode-map "F" 'bh/restrict-to-file-or-follow))
;;           'append)

;; (defun bh/narrow-to-org-subtree ()
;;   (widen)
;;   (org-narrow-to-subtree)
;;   (save-restriction
;;     (org-agenda-set-restriction-lock)))

;; (defun bh/narrow-to-subtree ()
;;   (interactive)
;;   (if (equal major-mode 'org-agenda-mode)
;;       (progn
;;         (org-with-point-at (org-get-at-bol 'org-hd-marker)
;;           (bh/narrow-to-org-subtree))
;;         (when org-agenda-sticky
;;           (org-agenda-redo)))
;;     (bh/narrow-to-org-subtree)))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defkey org-agenda-mode-map "N" 'bh/narrow-to-subtree))
;;           'append)

;; (defun bh/narrow-up-one-org-level ()
;;   (widen)
;;   (save-excursion
;;     (outline-up-heading 1 'invisible-ok)
;;     (bh/narrow-to-org-subtree)))

;; (defun bh/get-pom-from-agenda-restriction-or-point ()
;;   (or (and (marker-position org-agenda-restrict-begin) org-agenda-restrict-begin)
;;       (org-get-at-bol 'org-hd-marker)
;;       (and (equal major-mode 'org-mode) (point))
;;       org-clock-marker))

;; (defun bh/narrow-up-one-level ()
;;   (interactive)
;;   (if (equal major-mode 'org-agenda-mode)
;;       (progn
;;         (org-with-point-at (bh/get-pom-from-agenda-restriction-or-point)
;;           (bh/narrow-up-one-org-level))
;;         (org-agenda-redo))
;;     (bh/narrow-up-one-org-level)))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defkey org-agenda-mode-map "U" 'bh/narrow-up-one-level))
;;           'append)

;; (defun bh/narrow-to-org-project ()
;;   (widen)
;;   (save-excursion
;;     (bh/find-project-task)
;;     (bh/narrow-to-org-subtree)))

;; (defun bh/narrow-to-project ()
;;   (interactive)
;;   (if (equal major-mode 'org-agenda-mode)
;;       (progn
;;         (org-with-point-at (bh/get-pom-from-agenda-restriction-or-point)
;;           (bh/narrow-to-org-project)
;;           (save-excursion
;;             (bh/find-project-task)
;;             (org-agenda-set-restriction-lock)))
;;         (org-agenda-redo)
;;         (beginning-of-buffer))
;;     (bh/narrow-to-org-project)
;;     (save-restriction
;;       (org-agenda-set-restriction-lock))))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defkey org-agenda-mode-map "P" 'bh/narrow-to-project))
;;           'append)

;; (defvar bh/project-list nil)

;; (defun bh/view-next-project ()
;;   (interactive)
;;   (let (num-project-left current-project)
;;     (unless (marker-position org-agenda-restrict-begin)
;;       (goto-char (point-min))
;;       ; Clear all of the existing markers on the list
;;       (while bh/project-list
;;         (set-marker (pop bh/project-list) nil))
;;       (re-search-forward "Tasks to Refile")
;;       (forward-visible-line 1))

;;     ; Build a new project marker list
;;     (unless bh/project-list
;;       (while (< (point) (point-max))
;;         (while (and (< (point) (point-max))
;;                     (or (not (org-get-at-bol 'org-hd-marker))
;;                         (org-with-point-at (org-get-at-bol 'org-hd-marker)
;;                           (or (not (bh/is-project-p))
;;                               (bh/is-project-subtree-p)))))
;;           (forward-visible-line 1))
;;         (when (< (point) (point-max))
;;           (add-to-list 'bh/project-list (copy-marker (org-get-at-bol 'org-hd-marker)) 'append))
;;         (forward-visible-line 1)))

;;     ; Pop off the first marker on the list and display
;;     (setq current-project (pop bh/project-list))
;;     (when current-project
;;       (org-with-point-at current-project
;;         (setq bh/hide-scheduled-and-waiting-next-tasks nil)
;;         (bh/narrow-to-project))
;;       ; Remove the marker
;;       (setq current-project nil)
;;       (org-agenda-redo)
;;       (beginning-of-buffer)
;;       (setq num-projects-left (length bh/project-list))
;;       (if (> num-projects-left 0)
;;           (message "%s projects left to view" num-projects-left)
;;         (beginning-of-buffer)
;;         (setq bh/hide-scheduled-and-waiting-next-tasks t)
;;         (error "All projects viewed.")))))

;; (add-hook 'org-agenda-mode-hook
;;           '(lambda () (org-defkey org-agenda-mode-map "V" 'bh/view-next-project))
;;           'append)




;; Modifying faces for bulk-mark in org-agenda.el
;; Can't believe that actually worked

(defun org-agenda-bulk-mark (&optional arg)
  "Mark the entry at point for future bulk action."
  (interactive "p")
  (dotimes (i (or arg 1))
    (unless (org-get-at-bol 'org-agenda-diary-link)
      (let* ((m (org-get-at-bol 'org-hd-marker))
	     ov)
	(unless (org-agenda-bulk-marked-p)
	  (unless m (user-error "Nothing to mark at point"))
	  (push m org-agenda-bulk-marked-entries)
	  (setq ov (make-overlay (point-at-bol) (+ 2 (point-at-bol))))
	  (org-overlay-display ov (concat org-agenda-bulk-mark-char " ")
			       ;; (org-get-todo-face "TODO")
			       'org-todo		                  ;Modification
			       'evaporate)
	  (overlay-put ov 'type 'org-marked-entry-overlay))
	(end-of-line 1)
	(or (ignore-errors
	      (goto-char (next-single-property-change (point) 'org-hd-marker)))
	    (beginning-of-line 2))
	(while (and (get-char-property (point) 'invisible) (not (eobp)))
	  (beginning-of-line 2))
	(message "%d entries marked for bulk action"
		 (length org-agenda-bulk-marked-entries))))))

;; Copy file path

(defun xah-copy-file-path (&optional @dir-path-only-p)
  "Copy the current buffer's file path or dired path to `kill-ring'.
Result is full path.
If `universal-argument' is called first, copy only the dir path.

If in dired, copy the file/dir cursor is on, or marked files.

If a buffer is not file and not dired, copy value of `default-directory' (which is usually the “current” dir when that buffer was created)

URL `http://ergoemacs.org/emacs/emacs_copy_file_path.html'
Version 2017-08-25"
  (interactive "P")
  (let (($fpath
         (if (equal major-mode 'dired-mode)
             (progn
               (mapconcat 'identity (dired-get-marked-files) "\n"))
           (if (buffer-file-name)
               (buffer-file-name)
             (expand-file-name default-directory)))))
    (kill-new
     (if @dir-path-only-p
         (progn
           (message "Directory path copied: 「%s」" (file-name-directory $fpath))
           (file-name-directory $fpath))
       (progn
         (message "File path copied: 「%s」" $fpath)
         $fpath )))))



;; ========================================
;; ================ MACROS ================
;; ========================================

(fset 'fold-current-drawer
   (lambda (&optional arg) "Keyboard macro." (interactive "p") (kmacro-exec-ring-item (quote ([21 18 58 46 42 63 58 36 return tab] 0 "%d")) arg)))



;; ========================================
;; ================= KEYS =================
;; ========================================

(global-set-key [M-kanji] 'ignore)

;; (global-set-key (kbd "C-x C-g") 'xah-open-in-external-app)

;; Unset org-mode keys
(eval-after-load "org"
  '(progn
     (define-key org-mode-map (kbd "C-,") nil)))
;; other-window with neg argument for global-set-key
(defun other-window-reverse ()
    (interactive)
    (other-window -1))

;; Toggle modes
(global-set-key (kbd "C-c u") 'visual-line-mode)
(global-set-key (kbd "C-c y") 'zp/variable-pitch-mode)
(global-set-key (kbd "C-c s") 'scroll-bar-mode)
(global-set-key (kbd "C-c H") 'global-hl-line-mode)
(global-set-key (kbd "C-c g") 'display-line-numbers-mode)
(global-set-key (kbd "C-c L") 'org-store-link)
;; (global-set-key (kbd "C-c f") 'switch-main-font)
(global-set-key (kbd "C-c i") 'toggle-truncate-lines)
(global-set-key (kbd "C-c f") 'flyspell-mode)
(global-set-key (kbd "M-O")   'olivetti-mode)
(global-set-key (kbd "M-W")   'writeroom-mode)
(global-set-key (kbd "C-c w") 'zp/whitespace-mode-lines-tail)
(global-set-key (kbd "C-c W") 'whitespace-mode)

;; Prototype
;; Doesn't toggle, just turns on
;; (global-set-key (kbd "C-c h") (lambda () (interactive)
;; 				(global-hl-line-mode)
;; 				(global-linum-mode)))


;; Other toggles

;; Actions
(global-set-key (kbd "C-c c") 'calendar)
(global-set-key (kbd "C-c n") 'org-capture)
(global-set-key (kbd "C-c N") 'org-noter)
(global-set-key (kbd "C-c C-=") 'increment-integer-at-point)
(global-set-key (kbd "C-c C--") 'decrement-integer-at-point)
(global-set-key (kbd "C-c d") 'zp/helm-ispell-preselect)
(global-set-key (kbd "C-c R") 'org-display-inline-images)
(global-set-key (kbd "C-c P") 'package-list-packages)
(global-set-key (kbd "H-h") 'er/expand-region)
(global-set-key (kbd "C-S-c C-S-c") 'mc/edit-lines)
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)
(global-set-key (kbd "C-c T") 'zp/switch-theme)
(global-set-key (kbd "H-.") 'zp/echo-buffer-name)
(global-set-key (kbd "H-/") 'zp/echo-clock-string)
(global-set-key (kbd "H-y") 'helm-bibtex-with-local-bibliography)
(global-set-key (kbd "H-M-y") 'helm-bibtex-select-bib)
(global-set-key (kbd "C-x F") 'zp/unfill-document)
(global-set-key (kbd "M-Q") 'zp/unfill-context)
(global-set-key (kbd "C-c D") 'zp/bibtex-completion-message-key-last)
(global-set-key (kbd "H-<backspace>") 'yas-prev-field)
(global-set-key (kbd "C-c x") 'zp/toggle-org-latex-pdf-process)
;; (global-set-key (kbd "H-g") 'keyboard-quit)
(global-set-key (kbd "H-l") 'zp/switch-to-mu4e)
(global-set-key (kbd "H-M-l") 'mu4e-compose-new)
;; (global-set-key (kbd "H-m") 'zp/switch-to-magit)
(global-set-key (kbd "H-m") 'magit-status)

;; Clocking commands
(global-set-key (kbd "C-c C-x C-j") 'org-clock-goto)
(global-set-key (kbd "C-c C-x C-i") 'org-clock-in)
(global-set-key (kbd "C-c C-x C-o") 'org-clock-out)
(global-set-key (kbd "C-c C-x C-z") 'org-resolve-clocks)

;; Movements
(global-set-key (kbd "H-o") 'zp/switch-to-agenda)
(global-set-key (kbd "H-M-;") 'helm-chronos-add-timer)
(global-set-key (kbd "H-;") 'zp/switch-to-chronos)
(global-set-key (kbd "M-o") 'mode-line-other-buffer)
(global-set-key (kbd "H-j") 'other-window-reverse)
(global-set-key (kbd "H-k") 'other-window)
(global-set-key (kbd "C-x t") 'window-toggle-split-direction)
(global-set-key (kbd "C-x 4 1") 'zp/kill-other-buffer-and-window)

;; ace-window & avy-jump
(global-set-key (kbd "H-M-n") 'ace-window)
;; (global-set-key (kbd "H-n") 'avy-goto-word-1)
(global-set-key (kbd "H-n") 'avy-goto-char-timer)
;; (global-set-key (kbd "H-m") 'avy-goto-char)
(setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))

;; Usual shortcuts
(defun zp/org-agenda-main (&optional arg)
  (interactive "P")
  (org-agenda arg "n"))
(defun zp/org-agenda-tools (&optional arg)
  (interactive "P")
  (org-agenda arg "l"))
(defun zp/org-agenda-media (&optional arg)
  (interactive "P")
  (org-agenda arg "b"))
(defun zp/org-agenda-reading (&optional arg)
  (interactive "P")
  (org-agenda arg "r"))

(define-prefix-command 'agenda-map)
(global-set-key (kbd "<f9>") 'agenda-map)
(global-set-key (kbd "<f9> <f9>")  'zp/org-agenda-main)
(global-set-key (kbd "<f9> <f10>") 'zp/org-agenda-reading)
(global-set-key (kbd "<f9> <f11>") 'zp/org-agenda-media)
(global-set-key (kbd "<f9> <f12>") 'zp/org-agenda-tools)

;; Winner
(global-set-key (kbd "H-u") 'winner-undo)
(global-set-key (kbd "H-i") 'winner-redo)

;; EXPERIMENTAL
;; key-chord
;; (setq key-chord-two-keys-delay .020
;;       key-chord-one-key-delay .050)
;; (key-chord-define-global "df" 'avy-goto-char-2)

;; Doesn't really work: Clears the previous windows configuration
;; without being able to go back with winner-redo.
;; Better to use C-x z
;; (make-command-repeatable 'winner-undo)

(defun zp/kill-other-buffer-and-window ()
  "Kill the other buffer and window if there is more than one window."
  (interactive)
  (if (not (one-window-p))
      (progn
	(other-window 1)
	(kill-buffer-and-window))
    (error "There is only one window in the frame.")))

(defun zp/kill-indirect-buffer ()
  "Kill the current buffer if it is an indirect buffer."
  (interactive)
  (if (not (eq (buffer-base-buffer) nil))
      (progn
	(condition-case nil
	    (kill-buffer-and-window)
	  (error nil))
	(message "Killed indirect buffer and window.")
	(zp/play-sound-turn-page))
    (message "Not in an indirect buffer.")))

(defun zp/org-agenda-kill-other-buffer-and-window ()
  "Kill the other buffer and window if there is more than one window in `org-agenda’."
  (interactive)
  (if (not (string-match "*Org Agenda*" (buffer-name)))
      (other-window 1))
  (zp/kill-other-buffer-and-window)
  (zp/play-sound-turn-page))

(defun zp/org-agenda-tree-to-indirect-buffer (arg)
  "Open current tasks in other window, narrow it, and balance
windows."
  (interactive "P")
  (call-interactively 'org-agenda-tree-to-indirect-buffer current-prefix-arg)
  (if current-prefix-arg
      (setq org-last-indirect-buffer nil))
  (balance-windows)
  (other-window 1)
  (org-overview)
  (org-cycle)
  (widen)
  (org-reveal)
  (org-narrow-to-subtree)
  (zp/play-sound-turn-page))

(defun zp/org-agenda-tree-to-indirect-buffer-without-grabbing-focus (arg)
  (interactive "P")
  (zp/org-agenda-tree-to-indirect-buffer arg)
  (other-window -1))

(defun zp/org-agenda-tree-to-indirect-buffer-maximise (arg)
  (interactive "P")
  (zp/org-agenda-tree-to-indirect-buffer arg)
  (delete-other-windows))

(defun zp/org-agenda-tree-to-indirect-buffer-permanent (arg)
  (interactive "P")
  (let ((current-prefix-arg '(1)))
    (zp/org-agenda-tree-to-indirect-buffer arg)))



;; ========================================
;; ================ FACES =================
;; ========================================

;;; Truncate long buffer names
;; (require 'nadvice)
;; (defun my-truncate-buffer-name (buf-name)
;;   (let ((len (length buf-name)))
;;     (cond ((> len 20)
;;            (concat (substring buf-name 0 19)
;;                    "…"))
;;           (t buf-name))))
;; (advice-add 'powerline-buffer-id :filter-return 'my-truncate-buffer-name)

(defvar zp/powerline-text-height nil
  "Height of the text to be displayed in the modeline.")

(defun zp/pdf-view-midnight-mode-theme ()
  (setq pdf-view-midnight-colors
	`(,(face-attribute 'default :foreground) .
	  ,(face-attribute 'default :background))))

(defun zp/spaceline-theme (&optional arg)
  (spaceline-define-segment narrow
    "Display Narrowed when buffer is narrowed."
    (when (buffer-narrowed-p)
      "Narrow"))

  (spaceline-emacs-theme 'narrow)
  (spaceline-helm-mode)
  (spaceline-toggle-hud-off)
  (spaceline-toggle-mu4e-alert-segment-on)
  (spaceline-toggle-buffer-id-on)
  (setq powerline-height 45
	zp/powerline-text-height 0.95
	powerline-text-scale-factor 0.88
	powerline-default-separator 'arrow)

  (set-face-attribute 'powerline-active0 nil
  		      :height zp/powerline-text-height)
  (set-face-attribute 'powerline-active1 nil
  		      :height zp/powerline-text-height)
  (set-face-attribute 'powerline-active2 nil
		      :height zp/powerline-text-height)
  (set-face-attribute 'powerline-inactive0 nil
		      :height zp/powerline-text-height)
  (set-face-attribute 'powerline-inactive1 nil
		      :height zp/powerline-text-height)
  (set-face-attribute 'powerline-inactive2 nil
		      :height zp/powerline-text-height)
  (set-face-attribute 'mode-line nil
		      :height zp/powerline-text-height)
  (set-face-attribute 'mode-line-inactive nil
		      :height zp/powerline-text-height)



  (cond ((string= arg "dark")
	 (progn
	   (set-face-attribute 'powerline-active1 nil
			       :background "#6a182e")
	   (set-face-attribute 'powerline-active2 nil
			       :background "#400f1c")
	   (set-face-attribute 'powerline-inactive0 nil
			       :background "#3d4a80" :foreground "#dfe2f1")
	   (set-face-attribute 'powerline-inactive1 nil
			       :background "#293256" :foreground "#dfe2f1")
	   (set-face-attribute 'powerline-inactive2 nil
			       :background "#222222")
	   (set-face-attribute 'mode-line-inactive nil
			       :background "#3d4a80" :foreground "#666")
	   (set-face-attribute 'mode-line nil
			       :background "#222222")
	   (set-face-attribute 'mode-line-buffer-id nil
			       :foreground "DarkGoldenrod2" :weight 'bold)
	   (set-face-attribute 'mode-line-buffer-id-inactive nil
			       :foreground "white" :weight 'bold)
	   ))
	((string= arg "light")
	 (progn
	   (set-face-attribute 'powerline-active1 nil
			       :background "#476CCC" :foreground "DarkGoldenrod1")
	   (set-face-attribute 'powerline-active2 nil
			       :background "#5987FF")
	   (set-face-attribute 'powerline-inactive1 nil
			       :background "#b3c8ff")
	   (set-face-attribute 'powerline-inactive2 nil
			       :background "#bbbbbb")
	   (set-face-attribute 'mode-line-inactive nil
			       :background "#8fa0cc" :foreground "#666")
	   (set-face-attribute 'mode-line nil
			       :background "#666358" :foreground "#ddd")
	   (set-face-attribute 'mode-line-buffer-id nil
			       :foreground "DarkGoldenrod2" :weight 'bold)
	   (set-face-attribute 'mode-line-buffer-id-inactive nil
			       :foreground "black" :weight 'bold)
	   (set-face-attribute 'anzu-mode-line nil
			       :foreground "#c5adff")
	   )))
  )

(defface org-todo-todo '((t)) nil)
(defface org-todo-next '((t)) nil)
(defface org-todo-strt '((t)) nil)
(defface org-todo-done '((t)) nil)
(defface org-todo-stby '((t)) nil)
(defface org-todo-wait '((t)) nil)
(defface org-todo-cxld '((t)) nil)

(defun zp/org-todo-format-face (type face colour)
  (cond ((string= type "box")
	 (set-face-attribute face nil
			     :box '(:line-width 3 :style released-button)
			     :height 0.8
			     :weight 'bold
			     :foreground "white"
			     :background colour))
	((string= type "normal")
	 (set-face-attribute face nil
			     :box nil
			     :height 0.8
			     :background nil
			     :weight 'bold
			     :foreground colour))))

(defface org-priority-face-a '((t)) nil)
(defface org-priority-face-b '((t)) nil)
(defface org-priority-face-c '((t)) nil)
(defface org-priority-face-d '((t)) nil)
(defface org-priority-face-e '((t)) nil)

(defface org-tag-location    '((t :inherit 'org-tag)) nil)
(defface org-tag-todo        '((t :inherit 'org-tag)) nil)
(defface org-tag-important   '((t :inherit 'org-tag)) nil)
(defface org-tag-reading     '((t :inherit 'org-tag)) nil)
(defface org-tag-french      '((t :inherit 'org-tag)) nil)

(defun zp/org-format-face (face &rest args)
  (let (
	(foreground (plist-get args :foreground))
	(weight     (plist-get args :weight))
	(background (plist-get args :background)))
    (if (bound-and-true-p foreground)
	(set-face-attribute face nil :foreground foreground)
      (set-face-attribute face nil :foreground nil))
    (if (bound-and-true-p background)
	(set-face-attribute face nil :background background)
      (set-face-attribute face nil :background nil))
    (if (bound-and-true-p weight)
	(set-face-attribute face nil :weight weight)
      (set-face-attribute face nil :weight 'normal))))

(defun zp/set-fonts ()
  ;; Default font
  (set-face-attribute 'default nil
  		      :font "Iosevka Prog" :height 100 :weight 'normal)
  ;; variable-pitch & fixed-pitch
  (set-face-attribute 'variable-pitch nil
  		      :font "Bliss Pro Prog" :height 1.3)
  ;; (set-face-attribute 'variable-pitch nil
  ;; 		      :font "ITC American Typewriter Std" :height 1.2)
  		      ;; :family "Equity" :height 1.2 :slant 'normal)
  (set-face-attribute 'fixed-pitch-serif nil
		      :font "Iosevka Prog Slab" :height 1.0)

  ;; CJK fonts
  (set-fontset-font (frame-parameter nil 'font) 'han '("Noto Sans CJK JP"))
  (set-fontset-font (frame-parameter nil 'font) 'japanese-jisx0208 '("Noto Sans CJK JP"))
  (set-fontset-font (frame-parameter nil 'font) 'hangul '("Noto Sans CJK KR"))
  )

;; Fonts for emoji
;; (when (member "Symbola" (font-family-list))
;;   (set-fontset-font t 'unicode "Symbola" nil 'prepend))

;; Other fonts
;; :font "Source Code Pro" :height 100 :weight 'normal
;; :font "PragmataPro" :height 100 :weight 'normal
;; :font "Fira Code" :height 100 :weight 'normal
;; :font "Hack" :height 100 :weight 'normal



;; Line spacing
(setq-default line-spacing nil)

(defvar zp/line-spacing line-spacing
  "Default line-spacing.")
(defvar zp/line-spacing-variable-pitch 5
  "Default line-spacing for variable-pitch-mode.")

;; (setq zp/line-spacing nil
;;       zp/line-spacing-variable-pitch 5)

(make-variable-buffer-local
 (defvar zp/variable-pitch-mode-toggle nil
   "State of customised variable-pitch-mode."))
(defun zp/variable-pitch-mode ()
  "Enable variable-pitch-mode and changes line-spacing."
  (interactive)
  (cond ((bound-and-true-p zp/variable-pitch-mode-toggle)
	 (variable-pitch-mode)
	 (setq line-spacing zp/line-spacing
	       zp/variable-pitch-mode-toggle nil))
	(t
	 (variable-pitch-mode)
	 (setq line-spacing zp/line-spacing-variable-pitch
	       zp/variable-pitch-mode-toggle 1))))


(defvar zp/emacs-theme)

(defun zp/dark-theme ()
  (interactive)
  (setq zp/emacs-theme "dark")
  (load-theme 'base16-atelier-sulphurpool t)
  (zp/set-fonts)

  (set-face-attribute 'default nil :foreground "#BCAF8E" :background "#141414")
  (set-face-attribute 'org-todo nil :foreground "darkred")
  (set-face-attribute 'org-done nil :foreground "spring green")
  (set-face-attribute 'org-scheduled-today nil :foreground "CadetBlue")
  (set-face-attribute 'org-link nil :underline t)
  (set-face-attribute 'org-hide nil :foreground "#141414")
  (set-face-attribute 'org-agenda-dimmed-todo-face nil :foreground "LightSlateBlue")
  (set-face-attribute 'region nil :background "RoyalBlue4")
  (set-face-attribute 'helm-selection nil :background "RoyalBlue4") ;Darker Royal Blue
  (set-face-attribute 'org-agenda-clocking nil :background "RoyalBlue4")
  (set-face-attribute 'fringe nil :background "gray10")
  (set-face-attribute 'vertical-border nil :foreground "RoyalBlue1")
  (set-face-attribute 'org-agenda-structure nil :foreground "DodgerBlue1" :weight 'bold)
  (set-face-attribute 'hl-line nil :background "#202020")
  (set-face-attribute 'org-level-4 nil :foreground "#ed3971")
  (set-face-attribute 'org-meta-line nil :foreground "DodgerBlue3")
  (set-face-attribute 'header-line nil :foreground "#777")
  (set-face-attribute 'mu4e-system-face nil :foreground "SlateBlue")
  (set-face-attribute 'mu4e-modeline-face nil :foreground "LightBlue4")
  (set-face-attribute 'line-number nil :foreground "#969996" :background "#3B3B3B")
  (set-face-attribute 'secondary-selection nil :background "#3B3273")
  (set-face-attribute 'lui-track-bar nil :background "RoyalBlue4")


  (set-face-attribute 'zp/org-agenda-block-info-face nil
		      :foreground "violetred1"
		      :background "violetred4"
		      :height 0.8
		      :weight 'bold)
  (set-face-attribute 'zp/org-agenda-block-warning-face nil :foreground "red" :weight 'bold)

  (zp/org-todo-format-face 'box 'org-todo-todo "darkred")
  (zp/org-todo-format-face 'box 'org-todo-next "DodgerBlue1")
  (zp/org-todo-format-face 'box 'org-todo-strt "gold3")
  (zp/org-todo-format-face 'box 'org-todo-done "SpringGreen3")
  (zp/org-todo-format-face 'box 'org-todo-stby "SkyBlue4")
  (zp/org-todo-format-face 'box 'org-todo-wait "Skyblue4")
  (zp/org-todo-format-face 'box 'org-todo-cxld "turquoise")

  (zp/org-format-face 'org-priority-face-a :foreground "white" :background "darkred")
  (zp/org-format-face 'org-priority-face-b :foreground "darkred")
  (zp/org-format-face 'org-priority-face-c :foreground "yellow")
  (zp/org-format-face 'org-priority-face-d :foreground "ForestGreen")
  (zp/org-format-face 'org-priority-face-e :foreground "RoyalBlue")

  (zp/org-format-face 'org-tag-location  :weight 'bold :foreground "BlueViolet")
  (zp/org-format-face 'org-tag-todo   :weight 'bold :foreground "Skyblue4")
  (zp/org-format-face 'org-tag-important :weight 'bold :foreground "darkred")
  (zp/org-format-face 'org-tag-reading   :weight 'bold :foreground "DeepPink")
  (zp/org-format-face 'org-tag-french    :weight 'bold :foreground "DodgerBlue1")

  (zp/spaceline-theme "dark")
  (zp/pdf-view-midnight-mode-theme)
  )

(defun zp/light-theme ()
  (interactive)
  (setq zp/emacs-theme "light")
  (load-theme 'base16-google-light t)
  (zp/spaceline-theme)
  (zp/set-fonts)

  ;; (set-face-attribute 'org-todo-box nil :inverse-video t :foreground "white" :height 0.8 :weight 'bold :box nil)
  ;; (set-face-attribute 'default nil :background "cornsilk1") ;fff8dc
  (set-face-attribute 'default nil :foreground "#3c3836" :background "#fbf1c7")
  (set-face-attribute 'fringe nil :background "#e6deb8")
  (set-face-attribute 'org-hide nil :foreground "#fbf1c7")
  (set-face-attribute 'org-agenda-dimmed-todo-face nil :foreground "LightSlateBlue")
  (set-face-attribute 'org-scheduled-today nil :foreground "DodgerBlue4")
  (set-face-attribute 'region nil :background "SkyBlue1")
  (set-face-attribute 'hl-line nil :background "#ffea99")
  (set-face-attribute 'org-level-4 nil :foreground "#ed3971")
  (set-face-attribute 'org-link nil :underline t)
  (set-face-attribute 'org-agenda-clocking nil :background "LightBlue2")
  (set-face-attribute 'org-meta-line nil :foreground "DodgerBlue3")
  (set-face-attribute 'helm-selection nil :background "SteelBlue1")
  (set-face-attribute 'helm-visible-mark nil :background "goldenrod1")
  (set-face-attribute 'header-line nil :foreground "#ccc")
  (set-face-attribute 'mu4e-system-face nil :foreground "SlateBlue3")
  (set-face-attribute 'mu4e-modeline-face nil :foreground "LightBlue3")
  (set-face-attribute 'org-agenda-structure nil :foreground "DodgerBlue1" :weight 'bold)
  (set-face-attribute 'line-number nil :foreground "#636663" :background "#ccc6a4")
  ;; (set-face-attribute 'line-number-current-line nil :foreground "#707370" :background "#ccc6a4")
  (set-face-attribute 'secondary-selection nil :background "#d3ccff")
  (set-face-attribute 'lui-track-bar nil :background "RoyalBlue1")

  (set-face-attribute 'diff-hl-change nil :foreground "#3a81c3" :background "#3a81c3")
  (set-face-attribute 'diff-hl-insert nil :foreground "#7ccd7c" :background "#7ccd7c")
  (set-face-attribute 'diff-hl-delete nil :foreground "#ee6363" :background "#ee6363")

  (set-face-attribute 'zp/org-agenda-block-info-face nil
		      :foreground "violetred1"
		      :background "thistle2"
		      :height 0.8
		      :weight 'bold)
  (set-face-attribute 'zp/org-agenda-block-warning-face nil :foreground "red" :weight 'bold)

  (zp/org-todo-format-face 'normal 'org-todo-todo "red")
  (zp/org-todo-format-face 'normal 'org-todo-next "DodgerBlue1")
  (zp/org-todo-format-face 'normal 'org-todo-strt "gold3")
  (zp/org-todo-format-face 'normal 'org-todo-done "SpringGreen3")
  (zp/org-todo-format-face 'normal 'org-todo-stby "SkyBlue4")
  (zp/org-todo-format-face 'normal 'org-todo-wait "Skyblue4")
  (zp/org-todo-format-face 'normal 'org-todo-cxld "turquoise")

  (zp/org-format-face 'org-priority-face-a :foreground "white" :background "red")
  (zp/org-format-face 'org-priority-face-b :foreground "red")
  (zp/org-format-face 'org-priority-face-c :foreground "gold3")
  (zp/org-format-face 'org-priority-face-d :foreground "ForestGreen")
  (zp/org-format-face 'org-priority-face-e :foreground "RoyalBlue")

  (zp/org-format-face 'org-tag-location  :weight 'bold :foreground "BlueViolet")
  (zp/org-format-face 'org-tag-todo   :weight 'bold :foreground "Skyblue1")
  (zp/org-format-face 'org-tag-important :weight 'bold :foreground "red")
  (zp/org-format-face 'org-tag-reading   :weight 'bold :foreground "DeepPink")
  (zp/org-format-face 'org-tag-french    :weight 'bold :foreground "DodgerBlue1")

  (zp/spaceline-theme "light")
  (zp/pdf-view-midnight-mode-theme)
  )

(defun zp/switch-theme ()
  (interactive)
  (cond ((string= zp/emacs-theme "dark")
         (zp/light-theme))
	((string= zp/emacs-theme "light")
         (zp/dark-theme))))

;; Switch based on time-of-day
(defvar zp/night-begin 20
  "Hour when the night begins (24).")
(defvar zp/night-end 6
  "Hour when the night ends (24).")

(if (or
     (>= (nth 2 (decode-time)) zp/night-begin)
     (< (nth 2 (decode-time)) zp/night-end))
    (zp/dark-theme)
  (zp/light-theme))



;; DON'T GO THERE
;; YOU'LL LOSE YOUR SANITY



;; ;; Trying font-lock
;; (copy-face 'org-tag 'org-action-word-face)

;; (set-face-attribute 'org-action-word-face nil :foreground nil :weight 'bold :underline nil)n

;; (setq org-action-words "Prepare\\|Email\\|Read\\|Understand\\|Fill")
;; ;; Ideally, should use org-todo-keywords-1 and make a usable string with it rather than just copying everything here
;; (setq org-todo-words "TODO\\|NEXT\\|STRT\\|DONE\\|STBY\\|WAIT\\|CXLD")

;; ;; Can't figure out a way to make the regex work in a variable
;; ;; (setq problematic-regex (concat "\\(?:" org-todo-words "\\).*?\\(" org-action-words "\\)"))
;; ;; (setq problematic-regex "\\(?:TODO\\|NEXT\\|STRT\\|DONE\\|STBY\\|WAIT\\|CXLD\\).*?\\(Prepare\\|Email\\|Read\\|Understand\\|Fill\\)")
;; (defcustom problematic-regex "\\(?:TODO\\|NEXT\\|STRT\\|DONE\\|STBY\\|WAIT\\|CXLD\\).*?\\(Prepare\\|Email\\|Read\\|Understand\\|Fill\\)"
;;   "Just a fucking regex that doesn't want to work")

;; (font-lock-add-keywords
;;  'org-mode
;;  '(("\\(?:NEXT\\|TODO\\).*?\\(Prepare\\|Email\\)" 1 'org-action-word-face prepend))
;;  ;; '(("\\(?:TODO\\|NEXT\\|STRT\\|DONE\\|STBY\\|WAIT\\|CXLD\\).*?\\(Prepare\\|Email\\|Read\\|Understand\\|Fill\\)" 1 'org-action-word-face prepend))
;;  ;; '(((concat "\\(?:" org-todo-words "\\).*?\\(" org-action-words "\\)") 1 'org-action-word-face prepend))
;;  ;; '((regex-keywords 1 'org-action-word-face prepend))
;;  'append)

;; ;; (defun my-font-lock-restart ()
;; ;;   (interactive)
;; ;;   (setq font-lock-mode-major-mode nil)
;; ;;   (font-lock-fontify-buffer))

;; ;; (my-font-lock-restart)



;; ;; Trying text-properties
;; (setq org-finalize-agenda-hook
;;     (lambda ()
;;       (save-excursion
;;         (goto-char (point-min))
;;         (while (re-search-forward "(DONE)" nil t)
;;           (add-text-properties (match-beginning 0) (match-end 0)
;; 			       '(face org-done)))
;; 	(goto-char (point-min))
;;         (while (re-search-forward "(TODO)\\|(NEXT)\\|(STRT)\\|(SCHD)\\|(PREP)" nil t)
;;           (add-text-properties (match-beginning 0) (match-end 0)
;; 			       '(face org-todo)))
;;         (while (re-search-forward problematic-regex nil t)
;;           (add-text-properties (match-beginning 1) (match-end 1)
;; 			       '(face org-action-word-face)))
;; 	;; Remove mouse highlighting in org-agenda
;; 	(remove-text-properties
;;          (point-min) (point-max) '(mouse-face t))
;; 	)))

;; ;; (setq org-finalize-agenda-hook nil)

;; ;;   (add-text-properties (match-beginning 0) (point-at-eol)



;; Better archiving
;; Only works without prefix
;; Presumably not too stable

;; (defadvice org-archive-subtree (around fix-hierarchy activate)
;;   (let* ((fix-archive-p (and (not current-prefix-arg)
;;                              (not (use-region-p))))
;;          (afile (org-extract-archive-file (org-get-local-archive-location)))
;;          (buffer (or (find-buffer-visiting afile) (find-file-noselect afile))))
;;     ad-do-it
;;     (when fix-archive-p
;;       (with-current-buffer buffer
;;         (goto-char (point-max))
;;         (while (org-up-heading-safe))
;;         (let* ((olpath (org-entry-get (point) "ARCHIVE_OLPATH"))
;;                (path (and olpath (split-string olpath "/")))
;;                (level 1)
;;                tree-text)
;;           (when olpath
;;             (org-mark-subtree)
;;             (setq tree-text (buffer-substring (region-beginning) (region-end)))
;;             (let (this-command) (org-cut-subtree))
;;             (goto-char (point-min))
;;             (save-restriction
;;               (widen)
;;               (-each path
;;                 (lambda (heading)
;;                   (if (re-search-forward
;;                        (rx-to-string
;;                         `(: bol (repeat ,level "*") (1+ " ") ,heading)) nil t)
;;                       (org-narrow-to-subtree)
;;                     (goto-char (point-max))
;;                     (unless (looking-at "^")
;;                       (insert "\n"))
;;                     (insert (make-string level ?*)
;;                             " "
;;                             heading
;;                             "\n"))
;;                   (cl-incf level)))
;;               (widen)
;;               (org-end-of-subtree t t)
;;               (org-paste-subtree level tree-text))))))))



;; ========================================
;; ================ THEME =================
;; ========================================

;; Mark 1
;; (load-theme 'base16-atelier-sulphurpool t)

;; SML (Modeline)
;; (setq sml/no-confirm-load-theme t)
;; (setq sml/theme 'dark)
;; (setq sml/name-width '20)
;; (sml/setup)

;; Old theme switch
;; (setq dark-theme 'base16-ateliersulphurpool-dark
;;       light-theme 'base16-solarized-light)
;; (setq theme-mode 'dark-theme)

;; (defun switch-theme-mode ()
;;   "Switch the theme between dark and light mode."
;;   (interactive)
;;   (if (not (eq theme-mode 'dark))
;;       (progn
;; 	(load-theme dark-theme t)
;; 	(set-face-attribute 'org-done nil :foreground "spring green")
;; 	(set-face-attribute 'org-hide nil :foreground "#202746")
;; 	(set-face-attribute 'helm-selection nil :background "RoyalBlue4")
;; 	(set-face-attribute 'region nil :background "RoyalBlue4")
;; 	(set-face-attribute 'org-agenda-dimmed-todo-face nil :foreground "SkyBlue4")
;; 	(set-face-attribute 'org-agenda-clocking nil :background "RoyalBlue4")
;; 	(setq theme-mode 'dark))
;;     (progn
;;       (load-theme light-theme t)
;;       (set-face-attribute 'org-hide nil :foreground "#fdf6e3")
;;       (set-face-attribute 'helm-selection nil :background "RoyalBlue4")
;;       (set-face-attribute 'region nil :background "RoyalBlue4")
;;       (set-face-attribute 'org-agenda-dimmed-todo-face nil :foreground "LightSteelBlue3")
;;       (set-face-attribute 'org-agenda-clocking nil :background "RoyalBlue4")
;;       (setq theme-mode 'light))))

;; (switch-theme-mode)



;; ========================================
;; ================ FONTS =================
;; ========================================

(calendar-set-date-style 'iso)

;;; One of the first function I've written in emacs
;;; I don't really have a need for it now, but it still works just fine.

;; (defun switch-main-font ()
;;   "Switch the main font."
;;   (interactive)
;;   (cond ((or
;; 	  (eq (boundp 'main-font) nil)
;; 	  (eq main-font 'pragmata-font))
;; 	 ;; (set-face-attribute 'default nil
;; 	 ;; 		     :family "Source Code Pro" :height 110 :weight 'normal)           ;Necessary to reset weight
;; 	 (set-face-attribute 'default nil
;; 			     :family "PragmataPro Mono" :height 100 :weight 'normal)
;; 	 (set-face-attribute 'bold nil
;; 	 		     :weight 'normal)	 
;; 	 (set-face-attribute 'bold nil
;; 	 		     :weight 'bold)
;; 	 (setq-default line-spacing nil)
;; 	 ;; (switch-cjk-font "Noto Sans CJK JP Regular")
;; 	 (setq main-font 'source-font))
;; 	((eq main-font 'source-font)
;; 	 (set-face-attribute 'default nil
;; 			     :family "Source Code Pro" :height 100 :weight 'normal)
;; 	 (set-face-attribute 'bold nil
;; 	 		     :weight 'black)
;; 	 (setq-default line-spacing nil)
;; 	 ;; (switch-cjk-font "Unifont")
;; 	 (setq main-font 'pragmata-font))))

;; 	;; ((eq main-font 'consolas-font)
;; 	;;  (set-face-attribute 'default nil
;; 	;; 		     :family "Unifont" :height 110)
;; 	;;  (setq-default line-spacing 0.15)
;; 	;;  (switch-cjk-font "Unifont")
;; 	;;  (setq main-font 'unifont-font))))

;; (defun switch-cjk-font (cjk-font)
;;   "Switch the font used for CJK characters."
;;   (interactive)
;;   (set-fontset-font t 'hangul (font-spec :name cjk-font))
;;   (set-fontset-font t 'japanese-jisx0208 (font-spec :name cjk-font))
;;   (set-fontset-font t 'han (font-spec :name cjk-font)))

;; (setq main-font 'source-font)
;; (switch-main-font)

;; Prototype
(add-to-list 'org-export-filter-timestamp-functions
             #'endless/filter-timestamp)
(defun endless/filter-timestamp (trans back _comm)
  "Remove <> around time-stamps."
  (pcase back
    ((or `jekyll `html)
     (replace-regexp-in-string "&[lg]t;" "" trans))
    (`latex
     (replace-regexp-in-string "[<>]" "" trans))))

;; (setq-default org-display-custom-times t)
(setq org-time-stamp-custom-formats
      '("<%d %b %Y>" . "<%d/%m/%y %a %H:%M>"))


;; ========================================
;; ============= LATE MODES ===============
;; ========================================

;; Magnars's codes
;; expand-region causes weird flicker with repeated tasks if it's at the top
(require 'expand-region)
(require 'multiple-cursors)

;; Diminish
;; Allow minor modes to not have modeline display
(require 'diminish)

(diminish 'helm-mode)
(diminish 'auto-revert-mode)
(diminish 'anzu-mode)
(diminish 'yas-minor-mode)
(diminish 'which-key-mode)
(diminish 'volatile-highlights-mode)
(diminish 'undo-tree-mode)
(diminish 'whitespace-mode)



;; ========================================
;; =============== CUSTOM =================
;; ========================================

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)
(put 'narrow-to-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(auth-source-save-behavior nil)
 '(global-hl-line-mode t)
 '(helm-external-programs-associations
   (quote
    (("docx" . "lowriter")
     ("gpg" . "evince")
     ("mp4" . "smplayer")
     ("mkv" . "smplayer")
     ("dvi" . "evince")
     ("svg" . "inkscape")
     ("odt" . "lowriter")
     ("png" . "gimp")
     ("html" . "firefox")
     ("pdf" . "evince"))))
 '(ledger-reports
   (quote
    (("bal-last" "ledger bal ^expenses -p last\\ week and not commons and not swimming")
     ("bal-week" "ledger bal ^expenses -p this\\ week and not commons and not swimming")
     ("bal" "ledger -f /home/zaeph/org/main.ledger bal")
     ("reg" "%(binary) -f %(ledger-file) reg")
     ("payee" "%(binary) -f %(ledger-file) reg @%(payee)")
     ("account" "%(binary) -f %(ledger-file) reg %(account)"))))
 '(magit-log-arguments (quote ("--graph" "--color" "--decorate" "-n256")))
 '(magit-submodule-arguments (quote ("--recursive")))
 '(org-emphasis-alist
   (quote
    (("*" bold)
     ("/" italic)
     ("_" underline)
     ("=" org-code verbatim)
     ("~" org-verbatim verbatim)
     ("+"
      (:strike-through t))
     ("@" org-todo))))
 '(org-file-apps
   (quote
    (("\\.pdf\\'" . "evince %s")
     ("\\.epub\\'" . "ebook-viewer %s")
     ("\\.mobi\\'" . "ebook-viewer %s")
     ("\\.doc\\'" . "lowriter %s")
     (auto-mode . emacs)
     ("\\.mm\\'" . default)
     ("\\.x?html?\\'" . default)
     ("\\.pdf\\'" . default))))
 '(package-selected-packages
   (quote
    (el-patch diminish circe-notifications circe ob-async nov which-key eyebrowse diff-hl recentf-ext flycheck-pos-tip helm-projectile projectile clean-aindent-mode volatile-highlights duplicate-thing org-noter magit hydra highlight mu4e-alert ox-hugo org writeroom-mode anzu flycheck spaceline helm-chronos chronos olivetti multiple-cursors expand-region ace-window auto-minor-mode ledger-mode sublimity auctex smooth-scrolling yasnippet pdf-tools htmlize helm-bibtex free-keys evil color-theme base16-theme)))
 '(safe-local-variable-values
   (quote
    ((eval add-hook
	   (quote after-save-hook)
	   (function org-hugo-export-wim-to-md-after-save)
	   :append :local)
     nil
     (org-confirm-babel-evaluate)
     (after-save-hook . org-html-export-to-html))))
 '(send-mail-function (quote mailclient-send-it)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'LaTeX-narrow-to-environment 'disabled nil)
(put 'TeX-narrow-to-group 'disabled nil)
