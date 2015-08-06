# Equations
A plugin for dependent pattern-matching.

Copyright 2009-2015 Matthieu Sozeau `matthieu.sozeau@inria.fr`
Distributed under the terms of the GNU Lesser General Public
License Version 2.1 (see `LICENSE` for details).

This package is available on `opam` in the unstable repository:

    https://github.com/coq/repo-unstable

Alternatively, to compile equations, simply run:

    coq_makefile -f _CoqProject -o Makefile
    make

in the toplevel directory, with `coqc` and `ocamlc` in your path.

Then add the paths to your `.coqrc`:

    Add ML Path "/Users/mat/research/coq/equations/src".
    Add Rec LoadPath "/Users/mat/research/coq/equations/theories" as Equations.

Or install it:

    make install

As usual, you will need to run this command with the appropriate privileges
if the version of Coq you are using is installed system-wide, rather than
in your own directory. E.g. on Ubuntu, you would prefix the command with
`sudo` and then enter your user account password when prompted.

A preliminary documentation is available in `doc/` and
some examples in `test-suite/` and `examples/`. 
