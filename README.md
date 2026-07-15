[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaBibliographies.github.io/BibParser.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaBibliographies.github.io/BibParser.jl/dev)
[![Build Status](https://github.com/JuliaBibliographies/BibParser.jl/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/JuliaBibliographies/BibParser.jl/actions/workflows/ci.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/JuliaBibliographies/BibParser.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaBibliographies/BibParser.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# BibParser.jl

BibParser is a Julia package for parsing different bibliographic formats. The output are entries following the BibParser.jl structures. Instead of rewriting from scratch existing (and efficient) parsers in Julia, it is preferable to import them.

This package is not meant to be used on its own. Please check [Bibliography.jl](https://github.com/JuliaBibliographies/Bibliography.jl) for a package handling both import/export from various bibliographic formats.

The output of an example parsing a BibTeX file can be found at [baffier.fr/publications.html](https://baffier.fr/publications.html).

### BibTeX

A new parser is in used since `v0.1.12`. It is almost complete. Currently missing features follow:
- Applying the LaTeX commands from `@preamble`s entries to other entries
- Storing `@preamble`, `@string`, `@comment`, and free text to enable the reconstruction of the original `.bib` file
- Optional transformation of Unicode <-> LaTeX characters

### Citation Style Language (CSL-JSON)

Ongoing work.

### CFF

This implementation follows similar parsers: [cff-converter-python](https://github.com/citation-file-format/cff-converter-python) and [ruby-cff](https://github.com/citation-file-format/ruby-cff).
