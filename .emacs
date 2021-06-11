(modify-frame-parameters nil '((wait-for-wm . nil)))
;; .emacs

;;; uncomment this line to disable loading of "default.el" at startup
;; (setq inhibit-default-init t)

;; turn on font-lock mode
(global-font-lock-mode t)

(add-to-list 'load-path "~/.emacs.d/progmodes/")
(require 'f90plus)
(require 'outline-f90)

;; enable visual feedback on selections
(setq transient-mark-mode t)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(f90-break-delimiters "[-+\\*/><=, 	]")
 '(fill-column 130)
 '(fortran-continuation-indent 1)
 '(fortran-do-indent 1)
 '(fortran-if-indent 1)
 '(fortran-structure-indent 1)
 '(org-agenda-files (quote ("~/Dropbox/Orgzly/ToDo.org")))
 '(package-selected-packages
   (quote
    (texfrag use-package polymode fortpy f90-interface-browser dockerfile-mode color-theme-modern)))
 '(preview-gs-command "/home/abensonca/Galacticus/Tools/bin/gs-9540-linux-x86_64") ; GhostScript 9.540 is required to correctly adjust colors of LaTeX preview images to match dark theme
 '(preview-pdf-color-adjust-method t) ; Use LaTeX preview image color adjustment method suitable for GhostScript > 9.270
 '(texfrag-setup-alist
   (quote
    ((texfrag-html html-mode)
     (texfrag-eww eww-mode)
     (texfrag-sx sx-question-mode)
     (texfrag-prog prog-mode)
     (texfrag-trac-wiki trac-wiki-mode)
     (texfrag-markdown markdown-mode)
     (texfrag-org org-mode latex-mode f90plus-mode sgml-mode)))) ; Add all modes used in Galacticus source files here so that texfrag can process LaTeX fragments in them
 '(texfrag-subdir "/home/abensonca/Scratch/texfrag")
 '(tramp-ssh-controlmaster-options
   "-o ControlPath=~/.ssh/control:%%h:%%p:%%r -o ControlMaster=auto -o ControlPersist=yes" t)
 '(vc-follow-symlinks t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(preview-face ((t (:background "black" :foreground "white"))))
 '(preview-reference-face ((t nil))))

(setq vc-ignore-dir-regexp
      (format "\\(%s\\)\\|\\(%s\\)"
	      vc-ignore-dir-regexp
	      tramp-file-name-regexp))

(setq load-path
      (append '("~/.emacs.d/polymode")
              load-path))
(require 'polymode)

(define-hostmode poly-f90plus-hostmode :mode 'f90plus-mode)

(define-innermode poly-xml-multi-f90plus-innermode
  :mode 'sgml-mode
  :head-matcher (rx line-start (* (any space)) "!" (any "#@") space "<" (+ (any alpha)) (*? (not (any "/>"))) ">")
  :tail-matcher (rx line-start (* (any space)) "!" (any "#@") space "</" (+ (any alpha)) ">")
  :head-mode 'body
  :tail-mode 'body
  )

;; Standard XML match - THIS WILL EVENTUALLY BE DEPRECATED IN FAVOR OF THE PROPOSED BLOCK COMMENT FORM
(define-innermode poly-xml-single-f90plus-innermode
  :mode 'sgml-mode
  :head-matcher (rx line-start (* (any space)) "!"  (any "#@") space "<" (+ (any alpha)) (*? (not (any ">"))) "/>")
  :tail-matcher (rx "\n")
  :head-mode 'body
  :tail-mode 'body
  )

;; Standard LaTeX match - THIS WILL EVENTUALLY BE DEPRECATED IN FAVOR OF THE PROPOSED BLOCK COMMENT FORM
(define-innermode poly-latex-expr-f90plus-innermode
  :mode 'latex-mode
  :head-matcher (rx line-start (* (any space)) "!%")
  :tail-matcher (rx line-start (* (any space)) (not (any " !")))
  :head-mode 'body
  :tail-mode 'host
  )

;; Modified XML match that works with a proposed block comment form - THIS WILL EVENTUALLY BECOME THE STANDARD
(define-innermode poly-xml-mod-f90plus-innermode
  :mode 'sgml-mode
  :head-matcher (rx line-start (* (any space)) "!![")
  :tail-matcher (rx "!!]" (* (any space)) line-end)
  :head-mode 'host
  :tail-mode 'host
  )

;; Modified LaTeX match that works with a proposed block comment form - THIS WILL EVENTUALLY BECOME THE STANDARD
(define-innermode poly-latex-mod-f90plus-innermode
  :mode 'latex-mode
  :head-matcher (rx line-start (* (any space)) "!!{")
  :tail-matcher (rx "!!}" (* (any space)) line-end)
  :head-mode 'host
  :tail-mode 'host
  )

(define-polymode poly-f90plus-xml-mode
  :hostmode 'poly-f90plus-hostmode
  :innermodes '(poly-xml-multi-f90plus-innermode poly-xml-single-f90plus-innermode poly-xml-mod-f90plus-innermode poly-latex-expr-f90plus-innermode poly-latex-mod-f90plus-innermode))

(setq max-lisp-eval-depth 10000)
(setq max-specpdl-size 10000)

(setq auto-mode-alist
      (append auto-mode-alist
              '(("\\.inc$" . f90plus-mode)
              ("\\.Inc$" . f90plus-mode)
              ("\\.inc90$" . f90plus-mode)
              ("\\.Inc90$" . f90plus-mode)
              ("\\.F90$" . f90plus-mode)
              ("\\.f90t$" . f90plus-mode)
              ("\\.F90t$" . f90plus-mode))))

(add-to-list 'auto-mode-alist '("\\.F90$" . poly-f90plus-xml-mode))

;; Make F5 refresh the current buffer.
(defun refresh-file ()
  (interactive)
  (revert-buffer t t t)
  )

(global-set-key [f5] 'refresh-file)

(global-set-key (kbd "s-|") (kbd "¦"))

;; (customize-set-variable
;;  'tramp-ssh-controlmaster-options
;;  (concat
;;   "-o ControlPath=~/.ssh/control:%%h:%%p:%%r "
;;   "-o ControlMaster=auto -o ControlPersist=yes"))

(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  (when no-ssl (warn "\
Your version of Emacs does not support SSL connections,
which is unsafe because it allows man-in-the-middle attacks.
There are two things you can do about this warning:
1. Install an Emacs version that does support SSL and be safe.
2. Remove this warning from your init file so you won't see it again."))
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
  ;; and `package-pinned-packages`. Most users will not need or want to do this.
  (add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  )
(package-initialize)

;; Please set your themes directory to 'custom-theme-load-path
(add-to-list 'custom-theme-load-path
	     (file-name-as-directory "~/.emacs-themes"))

;; load your favorite theme
(load-theme 'dark-laptop t t)
(enable-theme 'dark-laptop)

;; org mode todo statuses
(setq org-todo-keywords
      '((sequence "TODO" "ONHOLD" "INPROGRESS" "|" "DONE")))

;; org mode priority typefaces
(setq org-priority-faces '((?A . (:foreground "green" :weight 'bold))
                           (?B . (:foreground "yellow"))
                           (?C . (:foreground "red"))))

;; Set texfrag-mode to be on globally in buffers that support it
(texfrag-global-mode)
