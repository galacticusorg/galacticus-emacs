;;; galacticus-docs.el --- Jump to Galacticus documentation from point -*- lexical-binding: t; -*-

;; Opens the online documentation for the functionClass at point, from either of
;; the two places a class is named:
;;
;;   * a source file, which *defines* a class --
;;
;;       !![
;;       <darkMatterProfileScaleRadius name="darkMatterProfileScaleRadiusJohnson2021">
;;       !!]
;;
;;   * a parameter file, which *selects* one --
;;
;;       <darkMatterProfileScaleRadius value="johnson2021"/>
;;
;; Both are documented on the family page `physics/<family>.html', the family
;; section carrying the anchor `physics-<family>' and each implementation the
;; anchor `physics-<implementationName>'.  A parameter file writes the family as
;; the element and the implementation's short label as `value', so appending the
;; label to the family reconstructs the name the source registers, and the two
;; cases converge on the same URL.
;;
;; This mirrors the `Ctrl+K Ctrl+G' command in the galacticus-code VSCode
;; extension, deliberately down to the key: `C-c C-g'.

;;; Code:

(require 'cl-lib)
(require 'browse-url)
;; `url-hexify-string'. It arrives transitively via `browse-url' today, but a
;; transitive require is not a guarantee -- ask for it outright.
(require 'url-util)

(defgroup galacticus-docs nil
  "Jump to the Galacticus documentation for the class at point."
  :group 'tools
  :prefix "galacticus-docs-")

(defcustom galacticus-docs-base-url "https://galacticus.readthedocs.io/en/latest/"
  "Base URL of the online Galacticus documentation.
Point this at a local or versioned build if needed."
  :type 'string
  :group 'galacticus-docs)

(defcustom galacticus-docs-schema-file nil
  "Path to the generated `parameters.xsd', or nil to search for it.
When nil, the directories above the current file are searched for
`schema/parameters.xsd' or `.vscode/schema/parameters.xsd'.

The schema is what distinguishes a functionClass selection from an
ordinary parameter.  Without it the command falls back to the naming
convention, which is right for real selections but cannot tell that,
say, a nodeComponent has no documentation page."
  :type '(choice (const :tag "Search for it" nil) file)
  :group 'galacticus-docs)

;;; URLs -----------------------------------------------------------------------

(defun galacticus-docs--anchor (name)
  "Reproduce Sphinx's standard-label id for NAME."
  (let ((id (downcase (concat "physics-" name))))
    (setq id (replace-regexp-in-string "[^a-z0-9]+" "-" id))
    (replace-regexp-in-string "\\(?:\\`-+\\|-+\\'\\)" "" id)))

(defun galacticus-docs--url (family name)
  "URL of the documentation section for NAME within FAMILY."
  (concat (file-name-as-directory galacticus-docs-base-url)
          "physics/" (url-hexify-string family) ".html#"
          (galacticus-docs--anchor name)))

(defun galacticus-docs--implementation-name (family label)
  "The name FAMILY's implementation LABEL is registered under in the source.
The capitalisation is fidelity to that name rather than a requirement:
`galacticus-docs--anchor' case-folds, so it does not change the URL."
  (concat family (capitalize (substring label 0 1)) (substring label 1)))

;;; Source files ---------------------------------------------------------------

(defun galacticus-docs--source-targets ()
  "Classes defined in the current buffer, as a list of (FAMILY NAME KIND)."
  (let ((targets nil))
    (save-excursion
      ;; Abstract base class: <functionClass ...> ... <name>NAME</name>.
      (goto-char (point-min))
      (while (re-search-forward
              "<functionClass\\b[^>]*>\\(?:.\\|\n\\)*?<name>[ \t\n]*\\([A-Za-z0-9_]+\\)[ \t\n]*</name>"
              nil t)
        (let ((name (match-string-no-properties 1)))
          (push (list name name 'class) targets)))
      ;; Implementation: <family name="familyImplementation">, where the name
      ;; begins with the tag followed by an upper-case letter.  That excludes
      ;; <method name="...">, <inputParameter name="...">, and friends.
      (goto-char (point-min))
      (while (re-search-forward
              "<\\([a-z][A-Za-z0-9]*\\)\\b[^>]*\\bname=\"\\([A-Za-z0-9_]+\\)\"" nil t)
        (let ((tag (match-string-no-properties 1))
              (name (match-string-no-properties 2)))
          (when (and (not (string= tag name))
                     (string-prefix-p tag name)
                     (let ((next (aref name (length tag))))
                       (and (>= next ?A) (<= next ?Z))))
            (push (list tag name 'implementation) targets)))))
    (cl-remove-duplicates (nreverse targets) :test #'equal :from-end t)))

;;; Parameter files ------------------------------------------------------------

(defconst galacticus-docs--tag-regexp
  "<\\(/?\\)\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\(\\(?:\"[^\"]*\"\\|'[^']*'\\|[^>\"']\\)*?\\)\\(/?\\)>"
  "Match an XML tag.
Captures: closing slash, name, attributes, self-closing slash.")

(defun galacticus-docs--value-attribute (attributes)
  "The `value' attribute in ATTRIBUTES, or nil."
  (when (string-match "\\bvalue[ \t\n]*=[ \t\n]*\\(?:\"\\([^\"]*\\)\"\\|'\\([^']*\\)'\\)"
                      attributes)
    (or (match-string 1 attributes) (match-string 2 attributes))))

(defun galacticus-docs--element-chain (position)
  "Elements at POSITION, innermost first, as a list of (TAG . VALUE).
Being inside a start tag picks that element; anywhere else falls through
to whatever encloses POSITION."
  (save-excursion
    (goto-char (point-min))
    (let ((stack nil) (direct nil) (done nil))
      (while (and (not done)
                  (re-search-forward galacticus-docs--tag-regexp nil t))
        (let* ((start (match-beginning 0))
               (end (match-end 0))
               (closing (string= (match-string-no-properties 1) "/"))
               (tag (match-string-no-properties 2))
               (attributes (match-string-no-properties 3))
               (self-closing (string= (match-string-no-properties 4) "/")))
          (cond
           ((> start position) (setq done t))
           ((< position end)
            ;; The cursor is inside this tag, so it is the innermost candidate
            ;; and must not also count as one of its own ancestors.
            (setq direct (cons tag (unless closing
                                     (galacticus-docs--value-attribute attributes)))))
           (closing
            (let ((match (cl-position tag stack :key #'car :test #'string=)))
              (when match (setq stack (nthcdr (1+ match) stack)))))
           ((not self-closing)
            (push (cons tag (galacticus-docs--value-attribute attributes)) stack)))))
      (append (when direct (list direct)) stack))))

;;; The schema -----------------------------------------------------------------

(defconst galacticus-docs--schema-section-start
  "<!-- functionClass selectors:")

(defconst galacticus-docs--schema-section-end
  "<!-- Enumeration-valued parameters:")

(defvar galacticus-docs--schema-cache nil
  "Cons of (KEY . TABLE), where KEY identifies the parsed file and its mtime.")

(defun galacticus-docs--find-schema ()
  "Locate the generated `parameters.xsd', or return nil."
  (or galacticus-docs-schema-file
      (let* ((file (galacticus-docs--buffer-file-name))
             (start (file-name-directory (or file default-directory))))
        (cl-loop for relative in '("schema/parameters.xsd" ".vscode/schema/parameters.xsd")
                 for root = (locate-dominating-file start relative)
                 when root return (expand-file-name relative root)))))

(defun galacticus-docs--parse-schema (path)
  "Parse PATH into a hash of family name -> list of implementation labels.
A family the schema declares without an enumeration maps to nil: it is
still a functionClass, there is simply no list to check a label against.
Only the first section of the schema is read; the second enumerates
ordinary label-valued parameters, which have no documentation page."
  (with-temp-buffer
    (insert-file-contents path)
    (goto-char (point-min))
    (when (search-forward galacticus-docs--schema-section-start nil t)
      (let ((from (point))
            (to (save-excursion
                  (if (search-forward galacticus-docs--schema-section-end nil t)
                      (match-beginning 0)
                    (point-max))))
            (families (make-hash-table :test #'equal)))
        (narrow-to-region from to)
        (goto-char (point-min))
        (let ((names nil))
          (while (re-search-forward "<xs:element name=\"\\([A-Za-z_][A-Za-z0-9_.-]*\\)\"" nil t)
            (push (cons (match-string-no-properties 1) (match-end 0)) names))
          (setq names (nreverse names))
          (cl-loop for (name . begin) in names
                   for rest on names
                   for limit = (if (cadr rest) (cdr (cadr rest)) (point-max))
                   do (let ((labels nil))
                        (goto-char begin)
                        (while (re-search-forward "<xs:enumeration value=\"\\([^\"]*\\)\"" limit t)
                          (push (match-string-no-properties 1) labels))
                        (puthash name (nreverse labels) families))))
        (widen)
        (and (> (hash-table-count families) 0) families)))))

(defun galacticus-docs--schema ()
  "The parsed schema for the current buffer, or nil if none can be found."
  (let ((path (galacticus-docs--find-schema)))
    (when (and path (file-readable-p path))
      (let ((key (cons path (file-attribute-modification-time
                             (file-attributes path)))))
        (unless (and galacticus-docs--schema-cache
                     (equal (car galacticus-docs--schema-cache) key))
          (setq galacticus-docs--schema-cache
                (cons key (galacticus-docs--parse-schema path))))
        (cdr galacticus-docs--schema-cache)))))

;;; Resolution -----------------------------------------------------------------

(defun galacticus-docs--label-p (value)
  "Non-nil if VALUE has the shape of an implementation label.
Used only when no schema is available, to rule out the numbers, lists and
expressions that make up most of a parameter file."
  (and (stringp value)
       (string-match-p "\\`[A-Za-z][A-Za-z0-9_]*\\'" value)))

(defun galacticus-docs--resolve (chain families)
  "The first element of CHAIN that names a class, as (FAMILY NAME KIND).
FAMILIES is the parsed schema, or nil to fall back on the naming convention."
  (cl-loop for (tag . value) in chain
           do (cond
               (families
                ;; Note a family declared without an enumeration maps to nil, so
                ;; presence must be tested against the `missing' sentinel rather
                ;; than by truthiness.
                (let ((labels (gethash tag families 'missing)))
                  (unless (eq labels 'missing)
                    (cond
                     ((null value)
                      ;; A family named with no value selects nothing, but its
                      ;; own page is still the useful thing to open.
                      (cl-return (list tag tag 'class)))
                     ((or (null labels) (member value labels))
                      (cl-return (list tag
                                       (galacticus-docs--implementation-name tag value)
                                       'implementation)))))))
               ((galacticus-docs--label-p value)
                (cl-return (list tag
                                 (galacticus-docs--implementation-name tag value)
                                 'implementation))))
           finally return nil))

;;; Entry point ----------------------------------------------------------------

(defun galacticus-docs--buffer-file-name ()
  "The file behind this buffer, seeing through polymode's indirect buffers."
  (or (buffer-file-name)
      (and (buffer-base-buffer) (buffer-file-name (buffer-base-buffer)))))

(defun galacticus-docs--source-file-p ()
  "Non-nil if this buffer holds Galacticus source rather than parameters."
  (let ((file (galacticus-docs--buffer-file-name)))
    (and file (string-match-p "\\.\\(?:F90\\|f90\\|inc\\|Inc\\|inc90\\|Inc90\\)\\'" file))))

(defun galacticus-docs--parameter-file-p ()
  "Non-nil if this buffer holds a Galacticus parameter file.
A `<parameters>' root is required: plenty of unrelated XML is not ours."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "<parameters[ \t\n>]" nil t)))

(defun galacticus-docs--open-source ()
  "Open documentation for a class defined in this buffer."
  (let ((targets (galacticus-docs--source-targets)))
    (cond
     ((null targets)
      (message "Galacticus: no functionClass or implementation definition in this file."))
     ((= (length targets) 1)
      (apply #'galacticus-docs--visit (car targets)))
     (t
      (let* ((choices (mapcar (lambda (target)
                                (cons (format "%s (%s)" (nth 1 target) (nth 2 target))
                                      target))
                              targets))
             (choice (completing-read "Open documentation for: " choices nil t)))
        (apply #'galacticus-docs--visit (cdr (assoc choice choices))))))))

(defun galacticus-docs--open-parameter ()
  "Open documentation for the class selected at point."
  (let ((chain (galacticus-docs--element-chain (point))))
    (if (null chain)
        (message "Galacticus: no parameter at point.")
      (let ((target (galacticus-docs--resolve chain (galacticus-docs--schema))))
        (if target
            (apply #'galacticus-docs--visit target)
          (message "Galacticus: <%s> does not select a functionClass implementation, so it has no documentation page."
                   (car (car chain))))))))

(defun galacticus-docs--visit (family name _kind)
  "Open the documentation for NAME within FAMILY."
  (let ((url (galacticus-docs--url family name)))
    (message "Galacticus: %s" url)
    (browse-url url)))

;;;###autoload
(defun galacticus-docs-open ()
  "Open the Galacticus documentation for the class at point.
In a source file the class defined by the file is used, with a prompt if
it defines more than one.  In a parameter file the class selected at
point is used, falling back to whichever class encloses point."
  (interactive)
  (cond
   ((galacticus-docs--source-file-p) (galacticus-docs--open-source))
   ((galacticus-docs--parameter-file-p) (galacticus-docs--open-parameter))
   (t (message "Galacticus: not a Galacticus source or parameter file."))))

;;; Minor mode -----------------------------------------------------------------

(defvar galacticus-docs-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Deliberately the same mnemonic as `Ctrl+K Ctrl+G' in the VSCode
    ;; extension.  Free in f90plus-mode, nxml-mode, sgml-mode and globally.
    (define-key map (kbd "C-c C-g") #'galacticus-docs-open)
    map)
  "Keymap for `galacticus-docs-mode'.")

;;;###autoload
(define-minor-mode galacticus-docs-mode
  "Bind a key to open the Galacticus documentation for the class at point."
  :lighter " GalDoc"
  :keymap galacticus-docs-mode-map)

;;;###autoload
(defun galacticus-docs-setup ()
  "Turn on `galacticus-docs-mode' in the modes that edit Galacticus files."
  (dolist (hook '(f90plus-mode-hook f90-mode-hook nxml-mode-hook sgml-mode-hook))
    (add-hook hook #'galacticus-docs-mode)))

(provide 'galacticus-docs)

;;; galacticus-docs.el ends here
