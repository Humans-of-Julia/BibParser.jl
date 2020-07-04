# BibParser.jl

BibParser is a Julia package for parsing different bibliographic formats. The output are entries following the BibInternal.jl structures. Instead of rewriting from scratch existing (and efficient) parsers in Julia, it is preferable to import them.

Currently, only a BibTeX parser is available, based on Automa.jl.

This package is not meant to be used on its own. Please check [Bibliography.jl]([https://](https://github.com/Azzaare/Bibliography.jl)) for a package handling both import/export from various bibliographic formats.
