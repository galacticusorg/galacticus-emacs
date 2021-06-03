# emacs-f90

This repo contains the configuration that I use for editing Galacticus source code in emacs.

Galacticus source files are modern Fortran, but with embedded sections of XML and LaTeX. I use [polymode](https://github.com/polymode/polymode) to handle these three separate languages in a single emacs buffer.

I also use a custom [f90-mode](https://jblevins.org/log/f90-mode) which I've modified to support these source files, along with a modified [outline-mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Outline-Mode.html) to allow collapsing/expanding sections of the code.

Finally, I use [texfrag-mode](https://github.com/TobiasZawada/texfrag) to render LaTeX math in the emacs window.

## Rendering LaTeX math

I use a dark theme in emacs. latex-preview should automatically detect the color theme and render the LaTeX equations with the same background and forground colors. This does not work in some versions of GhostScript, according to this [answer](https://emacs.stackexchange.com/a/56250). I use GhostScript [9.54.0](https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs9540/ghostscript-9.54.0-linux-x86_64.tgz) which renders the colors correctly.
