# emacs-f90

This repo contains the configuration that I use for editing Galacticus source code in emacs.

Galacticus source files are modern Fortran, but with embedded sections of XML and LaTeX. I use polymode to handle these three separate languages in a single emacs buffer.

I also use a custom f90-mode which I've modified to support these source files, along with a modified outline-mode to allow collapsing/expanding sections of the code.

Finally, I use texfrag-mode to render LaTeX math in the emacs window.

