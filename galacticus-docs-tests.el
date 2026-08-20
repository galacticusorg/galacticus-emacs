;;; galacticus-docs-tests.el --- Tests for galacticus-docs -*- lexical-binding: t; -*-

;; Run with:
;;
;;     emacs -Q --batch -L . -l galacticus-docs-tests.el \
;;           -f ert-run-tests-batch-and-exit
;;
;; The cases mirror those in the galacticus-code VSCode extension, so that the
;; two editors are held to the same behaviour.

;;; Code:

(require 'ert)
(require 'galacticus-docs)

(defconst galacticus-docs-tests--docs
  "https://galacticus.readthedocs.io/en/latest/physics/")

(defconst galacticus-docs-tests--parameters
  "<?xml version='1.0' encoding='UTF-8'?>
<parameters>
  <formatVersion>2</formatVersion>

  <darkMatterProfileScaleRadius value=\"concentrationLimiter\">
    <concentrationMinimum value=\"4.0\"/>
    <darkMatterProfileScaleRadius value=\"johnson2021\">
      <energyBoost value=\"0.6773\"/>
    </darkMatterProfileScaleRadius>
  </darkMatterProfileScaleRadius>

  <criticalOverdensity value=\"sphericalCollapseClsnlssMttrCsmlgclCnstnt\"/>

  <componentSatellite value=\"orbiting\"/>

  <mergerTreeMassResolution value=\"fixed\">
    <massResolution value=\"3.0e7\"/>
  </mergerTreeMassResolution>

  <nodeOperator value='multi'>
    <!-- Halo angular momentum -->
    <nodeOperator value=\"haloAngularMomentumVitvitska2002\"/>
  </nodeOperator>

  <toleranceAbsoluteMass value=\"1.0e-6\"/>
</parameters>
")

;; A cut-down stand-in for the generated schema: the two section comments the
;; command keys on, a family with enumerated labels, a family declared without an
;; enumeration, and one enumerated parameter in the *second* section that must
;; not be mistaken for a functionClass.
(defconst galacticus-docs-tests--schema
  "<?xml version=\"1.0\"?>
<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\">
  <!-- functionClass selectors: value restricted to valid implementations. -->
  <xs:element name=\"darkMatterProfileScaleRadius\">
   <xs:complexType mixed=\"true\">
    <xs:attribute name=\"value\" use=\"optional\">
     <xs:simpleType><xs:restriction base=\"xs:string\">
      <xs:enumeration value=\"concentrationLimiter\"/>
      <xs:enumeration value=\"johnson2021\"/>
     </xs:restriction></xs:simpleType>
    </xs:attribute>
   </xs:complexType>
  </xs:element>
  <xs:element name=\"criticalOverdensity\">
   <xs:complexType mixed=\"true\">
    <xs:attribute name=\"value\" type=\"xs:string\" use=\"optional\"/>
   </xs:complexType>
  </xs:element>
  <xs:element name=\"mergerTreeMassResolution\">
   <xs:complexType mixed=\"true\">
    <xs:attribute name=\"value\" use=\"optional\">
     <xs:simpleType><xs:restriction base=\"xs:string\">
      <xs:enumeration value=\"fixed\"/>
     </xs:restriction></xs:simpleType>
    </xs:attribute>
   </xs:complexType>
  </xs:element>
  <xs:element name=\"nodeOperator\">
   <xs:complexType mixed=\"true\">
    <xs:attribute name=\"value\" use=\"optional\">
     <xs:simpleType><xs:restriction base=\"xs:string\">
      <xs:enumeration value=\"haloAngularMomentumVitvitska2002\"/>
      <xs:enumeration value=\"multi\"/>
     </xs:restriction></xs:simpleType>
    </xs:attribute>
   </xs:complexType>
  </xs:element>
  <!-- Enumeration-valued parameters: value restricted to allowed labels. -->
  <xs:element name=\"componentSatellite\">
   <xs:complexType mixed=\"true\">
    <xs:attribute name=\"value\" use=\"optional\">
     <xs:simpleType><xs:restriction base=\"xs:string\">
      <xs:enumeration value=\"orbiting\"/>
     </xs:restriction></xs:simpleType>
    </xs:attribute>
   </xs:complexType>
  </xs:element>
</xs:schema>
")

(defconst galacticus-docs-tests--implementation
  "  !![
  <exampleFamily name=\"exampleFamilyWorkedExample\">
   <description>An implementation used only by these tests.</description>
  </exampleFamily>
  !!]
module Example_Worked_Example
end module Example_Worked_Example
")

(defconst galacticus-docs-tests--class
  "  !![
  <functionClass docformat=\"rst\">
   <name>exampleFamily</name>
   <descriptiveName>Example Family</descriptiveName>
   <description>A family used only by these tests.</description>
  </functionClass>
  !!]
module Example_Family
end module Example_Family
")

(defvar galacticus-docs-tests--visited nil
  "URL the command last tried to open, or nil.")

(defvar galacticus-docs-tests--message nil
  "Message the command last emitted in place of opening a URL.")

(defun galacticus-docs-tests--run (contents file &optional point-search column)
  "Invoke the command over CONTENTS, pretending the buffer visits FILE.
Point is put on the first line matching POINT-SEARCH, at COLUMN if given,
otherwise just inside the tag the search string starts."
  (let ((galacticus-docs-tests--visited nil)
        (galacticus-docs-tests--message nil))
    (with-temp-buffer
      (insert contents)
      (setq buffer-file-name file)
      (goto-char (point-min))
      (when point-search
        (should (search-forward point-search nil t))
        (goto-char (match-beginning 0))
        (forward-char (or column 2)))
      (cl-letf (((symbol-function 'browse-url)
                 (lambda (url &rest _) (setq galacticus-docs-tests--visited url)))
                ((symbol-function 'message)
                 (lambda (format &rest args)
                   (setq galacticus-docs-tests--message (apply #'format format args)))))
        (galacticus-docs-open))
      (setq buffer-file-name nil))
    (cons galacticus-docs-tests--visited galacticus-docs-tests--message)))

(defmacro galacticus-docs-tests--with-workspace (schema-p &rest body)
  "Run BODY in a temporary workspace, with the schema present when SCHEMA-P."
  (declare (indent 1))
  `(let* ((root (make-temp-file "galacticus-docs-tests" t))
          (galacticus-docs-schema-file nil)
          (galacticus-docs--schema-cache nil)
          (parameters (expand-file-name "parameters.xml" root)))
     (unwind-protect
         (progn
           (when ,schema-p
             (make-directory (expand-file-name "schema" root) t)
             (with-temp-file (expand-file-name "schema/parameters.xsd" root)
               (insert galacticus-docs-tests--schema)))
           ,@body)
       (delete-directory root t))))

;;; Parameter files ------------------------------------------------------------

(ert-deftest galacticus-docs-test-selection ()
  "A functionClass selection opens the implementation section."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<darkMatterProfileScaleRadius value=\"johnson2021\""))
                   (concat galacticus-docs-tests--docs
                           "darkMatterProfileScaleRadius.html"
                           "#physics-darkmatterprofilescaleradiusjohnson2021")))))

(ert-deftest galacticus-docs-test-cursor-anywhere ()
  "The cursor may sit anywhere inside the element."
  (galacticus-docs-tests--with-workspace t
    (let ((expected (concat galacticus-docs-tests--docs
                            "darkMatterProfileScaleRadius.html"
                            "#physics-darkmatterprofilescaleradiusjohnson2021")))
      ;; On the element name, on the attribute name, and inside the value.
      (dolist (column '(4 32 42))
        (should (equal (car (galacticus-docs-tests--run
                             galacticus-docs-tests--parameters parameters
                             "<darkMatterProfileScaleRadius value=\"johnson2021\"" column))
                       expected))))))

(ert-deftest galacticus-docs-test-single-quoted-value ()
  "A single-quoted value is read."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<nodeOperator value='multi'"))
                   (concat galacticus-docs-tests--docs
                           "nodeOperator.html#physics-nodeoperatormulti")))))

(ert-deftest galacticus-docs-test-family-without-enumeration ()
  "A family the schema does not enumerate is still resolved."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<criticalOverdensity"))
                   (concat galacticus-docs-tests--docs
                           "criticalOverdensity.html"
                           "#physics-criticaloverdensitysphericalcollapseclsnlssmttrcsmlgclcnstnt")))))

(ert-deftest galacticus-docs-test-innermost-wins ()
  "The innermost selection beats the one enclosing it."
  (galacticus-docs-tests--with-workspace t
    (let ((url (car (galacticus-docs-tests--run
                     galacticus-docs-tests--parameters parameters
                     "<darkMatterProfileScaleRadius value=\"johnson2021\""))))
      (should (string-suffix-p "physics-darkmatterprofilescaleradiusjohnson2021" url))
      (should-not (string-match-p "concentrationlimiter" url)))))

(ert-deftest galacticus-docs-test-sub-parameter-walks-out ()
  "A sub-parameter resolves to the class that defines it."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<massResolution value=\"3.0e7\""))
                   (concat galacticus-docs-tests--docs
                           "mergerTreeMassResolution.html"
                           "#physics-mergertreemassresolutionfixed")))))

(ert-deftest galacticus-docs-test-comment-walks-out ()
  "A comment inside a class block resolves to that class."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<!-- Halo angular momentum -->"))
                   (concat galacticus-docs-tests--docs
                           "nodeOperator.html#physics-nodeoperatormulti")))))

(ert-deftest galacticus-docs-test-node-component-declined ()
  "A nodeComponent looks like a selection but has no page, so is declined."
  (galacticus-docs-tests--with-workspace t
    (let ((result (galacticus-docs-tests--run
                   galacticus-docs-tests--parameters parameters
                   "<componentSatellite")))
      (should-not (car result))
      (should (string-match-p "componentSatellite" (cdr result)))
      (should (string-match-p "does not select a functionClass" (cdr result))))))

(ert-deftest galacticus-docs-test-plain-parameter-declined ()
  "A plain-valued parameter with no class above it is declined."
  (galacticus-docs-tests--with-workspace t
    (let ((result (galacticus-docs-tests--run
                   galacticus-docs-tests--parameters parameters
                   "<toleranceAbsoluteMass")))
      (should-not (car result))
      (should (string-match-p "does not select a functionClass" (cdr result))))))

(ert-deftest galacticus-docs-test-foreign-xml-not-claimed ()
  "XML without a <parameters> root is not claimed."
  (galacticus-docs-tests--with-workspace t
    (let ((result (galacticus-docs-tests--run
                   "<project>\n  <target value=\"build\"/>\n</project>\n"
                   (expand-file-name "other.xml" root)
                   "<target")))
      (should-not (car result))
      (should (string-match-p "not a Galacticus source or parameter file" (cdr result))))))

;;; Without a schema -----------------------------------------------------------

(ert-deftest galacticus-docs-test-fallback-resolves-selection ()
  "Without a schema a real selection still resolves, on the convention alone."
  (galacticus-docs-tests--with-workspace nil
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<darkMatterProfileScaleRadius value=\"johnson2021\""))
                   (concat galacticus-docs-tests--docs
                           "darkMatterProfileScaleRadius.html"
                           "#physics-darkmatterprofilescaleradiusjohnson2021")))))

(ert-deftest galacticus-docs-test-fallback-declines-numeric ()
  "Without a schema a numeric value is still declined."
  (galacticus-docs-tests--with-workspace nil
    (should-not (car (galacticus-docs-tests--run
                      galacticus-docs-tests--parameters parameters
                      "<toleranceAbsoluteMass")))))

(ert-deftest galacticus-docs-test-fallback-accepts-node-component ()
  "Documents the limit of the fallback: a nodeComponent cannot be told apart."
  (galacticus-docs-tests--with-workspace nil
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--parameters parameters
                         "<componentSatellite"))
                   (concat galacticus-docs-tests--docs
                           "componentSatellite.html#physics-componentsatelliteorbiting")))))

;;; Source files ---------------------------------------------------------------

(ert-deftest galacticus-docs-test-source-implementation ()
  "A concrete implementation opens its own section."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--implementation
                         (expand-file-name "implementation.F90" root)))
                   (concat galacticus-docs-tests--docs
                           "exampleFamily.html#physics-examplefamilyworkedexample")))))

(ert-deftest galacticus-docs-test-source-class ()
  "A base class opens the family section."
  (galacticus-docs-tests--with-workspace t
    (should (equal (car (galacticus-docs-tests--run
                         galacticus-docs-tests--class
                         (expand-file-name "_class.F90" root)))
                   (concat galacticus-docs-tests--docs
                           "exampleFamily.html#physics-examplefamily")))))

;;; Configuration --------------------------------------------------------------

(ert-deftest galacticus-docs-test-base-url ()
  "`galacticus-docs-base-url' is honoured, with or without a trailing slash."
  (galacticus-docs-tests--with-workspace t
    (dolist (base '("https://example.test/docs" "https://example.test/docs/"))
      (let ((galacticus-docs-base-url base))
        (should (string-prefix-p
                 "https://example.test/docs/physics/"
                 (car (galacticus-docs-tests--run
                       galacticus-docs-tests--parameters parameters
                       "<criticalOverdensity"))))))))

(provide 'galacticus-docs-tests)

;;; galacticus-docs-tests.el ends here
