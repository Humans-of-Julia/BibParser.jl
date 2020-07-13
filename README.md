# BibParser.jl

BibParser is a Julia package for parsing different bibliographic formats. The output are entries following the BibInternal.jl structures. Instead of rewriting from scratch existing (and efficient) parsers in Julia, it is preferable to import them.

This package is not meant to be used on its own. Please check [Bibliography.jl]([https://](https://github.com/Azzaare/Bibliography.jl)) for a package handling both import/export from various bibliographic formats.

##### BibTeX

Currently, only a BibTeX parser is available, based on Automa.jl. Some restrictions exist regarding the BibTeX grammar.
- `@string`, `@preamble`, and `@comment` are currently not accepted
- when the field value is delimited by braces (`{`, `}`), nested braces are not necessarily recognized correctly. However, nested braces within quoted value are fine
- value are parsed but not interpreted regarding their LaTeX syntax. It is preferable to use unicode syntax.

Those restrictions are expected to be lifted in the future.