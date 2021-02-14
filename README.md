[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://Humans-of-Julia.github.io/BibParser.jl/dev)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://Humans-of-Julia.github.io/BibParser.jl/stable)
[![Build Status](https://github.com/Humans-of-Julia/BibParser.jl/workflows/CI/badge.svg)](https://github.com/Humans-of-Julia/BibParser.jl/actions)
[![codecov](https://codecov.io/gh/Humans-of-Julia/BibParser.jl/branch/master/graph/badge.svg?token=zkneHUR45j)](https://codecov.io/gh/Humans-of-Julia/BibParser.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# BibParser.jl

BibParser is a Julia package for parsing different bibliographic formats. The output are entries following the BibParser.jl structures. Instead of rewriting from scratch existing (and efficient) parsers in Julia, it is preferable to import them.

This package is not meant to be used on its own. Please check [Bibliography.jl]([https://](https://github.com/Humans-of-Julia/Bibliography.jl)) for a package handling both import/export from various bibliographic formats.

The output of an example parsing a BibTeX file can be found at [baffier.fr/publications.html](https://baffier.fr/publications.html).

### BibTeX

Two parsers are available at the moment. The main one is based on [JuliaTeX/BibTeX.jl](https://github.com/JuliaTeX/BibTeX.jl) and can be found in the `bibtex.jl` file.

The second one uses [Automa.jl](https://github.com/BioJulia/Automa.jl). Some restrictions exist regarding the BibTeX grammar, please check `bibtex_automa.jl` for the details.
- `@string`, `@preamble`, and `@comment` are currently not accepted
- when the field value is delimited by braces (`{`, `}`), nested braces are not necessarily recognized correctly. However, nested braces within quoted value are fine
- value are parsed but not interpreted regarding their LaTeX syntax. It is preferable to use unicode syntax.
Those restrictions are expected to be lifted in the future.

On long term, a parser based on [Tokenize.jl](https://github.com/JuliaLang/Tokenize.jl) is expected.

### Citation Style Language (CSL-JSON)

Ongoing work.