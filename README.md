# emacs-f90

This repo contains an emacs configuration that can be used for editing Galacticus source code in emacs.

Galacticus source files are modern Fortran, but with embedded sections of XML and LaTeX. It is recommended to use [polymode](https://github.com/polymode/polymode) to handle these three separate languages in a single emacs buffer.

Also provided is a a custom [f90-mode](https://jblevins.org/log/f90-mode) which has been modified to support these source files, along with a modified [outline-mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Outline-Mode.html) to allow collapsing/expanding sections of the code.

Finally, [texfrag-mode](https://github.com/TobiasZawada/texfrag) is used to render LaTeX math in the emacs window.

## Usage

`C-c C-p C-d` render all LaTeX math in the buffer.

`C-c C-g` open the online documentation for the functionClass at point. This
works in two places:

* **A source file**, which *defines* a class — the class the file defines is
  used, with a prompt if it defines more than one.
* **A parameter file**, which *selects* one — put point on a parameter such as
  `<darkMatterProfileScaleRadius value="johnson2021"/>` and the implementation's
  section of the documentation opens. Anywhere inside the element works, and if
  point is on something that is not a selection (a sub-parameter, or a comment)
  the enclosing class is used, which is where that sub-parameter is documented.

The binding matches `Ctrl+K Ctrl+G` in the
[VSCode extension](https://github.com/galacticusorg/galacticus-code), so the two
editors behave the same way.

## Example

A screenshot showing an example of LaTeX math rendered in the buffer:

![Screenshot_20210603_165908](https://user-images.githubusercontent.com/7468651/120726489-03e98300-c48d-11eb-9f51-50a31598cbb5.png)

A screenshow showing mixed Fortran and XML in a single buffer with appropriate syntax highlighting and indentation for each:

![Screenshot_20210603_165934](https://user-images.githubusercontent.com/7468651/120726511-1368cc00-c48d-11eb-99b7-94e505b26fc5.png)

## Implementation notes

### Opening documentation from point

`galacticus-docs.el` maps whatever is at point onto a documentation URL. Both
kinds of file end up at the same place: the family page `physics/<family>.html`,
at the anchor `physics-<name>`. A source file names the class outright; a
parameter file writes the family as the element and the implementation's short
label as `value`, so appending the label to the family reconstructs the name the
source registers.

Whether a parameter is a functionClass selection at all is read from the
generated `parameters.xsd`, searched for upwards from the file being edited as
`schema/parameters.xsd` or `.vscode/schema/parameters.xsd`, or set explicitly
via `galacticus-docs-schema-file`. This matters because the naming convention
alone cannot tell a functionClass from a nodeComponent, and a nodeComponent such
as `<componentSatellite value="orbiting"/>` has no documentation page. Without a
schema the command falls back to the convention, which is right for real
selections but cannot warn about the rest.

Run the tests with:

```bash
emacs -Q --batch -L . -l galacticus-docs-tests.el -f ert-run-tests-batch-and-exit
```

### Rendering LaTeX math

If you use a dark theme in emacs. [preview-latex](https://www.gnu.org/software/auctex/manual/preview-latex.html) should automatically detect the color theme and render the LaTeX equations with the same background and forground colors. This does not work in some versions of GhostScript, according to this [answer](https://emacs.stackexchange.com/a/56250). It is recommended to use GhostScript [9.54.0](https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs9540/ghostscript-9.54.0-linux-x86_64.tgz) which renders the colors correctly.
