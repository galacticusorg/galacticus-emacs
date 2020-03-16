;; Clean code folding via Outline minor mode.
(add-hook 'f90plus-mode-hook 'outline-minor-mode)

;; Show all headings but no content in Outline mode.
(add-hook 'outline-minor-mode-hook
	  (defun my-outline-overview ()
	    "Show only outline headings."
	    (outline-show-all)
	    (outline-hide-body)))

;; Tab to "zoom in" on a function, backtab to "zoom out" to the outline.
(global-set-key (kbd "<f1>") 'outline-toggle-children)

(add-hook 'f90plus-mode-hook
	  (defun my-outline-fortran ()
	    "Fold definitions in Fortran."
	    (setq outline-regexp
	  	  (rx (or
	  	       ;; Module and interface blocks.
	  	       (group (group (* space)) (or "module" "interface"))
	  	       ;; Procedures and type definitions.
	  	       (group
	  		(group (* space))
	  		(*? (or "pure " "impure " "elemental "))
	  		(or "function" "subroutine" "interface" "type" "type,")
	  		(group (+ space))))))
                    ))


(provide 'outline-f90)
