[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://Humans-of-Julia.github.io/BibParser.jl/dev)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://Humans-of-Julia.github.io/BibParser.jl/stable)
[![Build Status](https://github.com/Humans-of-Julia/BibParser.jl/workflows/CI/badge.svg)](https://github.com/Humans-of-Julia/BibParser.jl/actions)
[![codecov](https://codecov.io/gh/Humans-of-Julia/BibParser.jl/branch/master/graph/badge.svg?token=zkneHUR45j)](https://codecov.io/gh/Humans-of-Julia/BibParser.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Discord chat](https://img.shields.io/discord/762167454973296644.svg?logo=discord&colorB=7289DA&style=flat-square)](https://discord.gg/7KC28q98nP)

# BibParser.jl

BibParser is a Julia package for importing bibliographic formats into
`BibInternal.Entry` and lossless `BibInternal.BibliographyDocument` values.
The supported formats are BibTeX, BibLaTeX, RIS, CFF 1.2, CSL-JSON, EndNote
XML, and MODS 3.x.

This package is not meant to be used on its own. Please check [Bibliography.jl]([https://](https://github.com/Humans-of-Julia/Bibliography.jl)) for a package handling both import/export from various bibliographic formats.

The output of an example parsing a BibTeX file can be found at [baffier.fr/publications.html](https://baffier.fr/publications.html).

BibTeX, BibLaTeX, and RIS are available in the core package. Formats backed by
external parsing libraries are package extensions:

- load `YAML` and `JSONSchema` to enable CFF;
- load `JSON3` to enable CSL-JSON;
- load `EzXML` to enable EndNote XML and MODS.

For example:

```julia
using BibParser, JSON3
document = parse_bibliography(read("references.json", String); format = :CSL)
```

### BibTeX and BibLaTeX

A new parser is in use since `v0.1.12`. It preserves entries, string macros,
preambles, comments, and free text in the lossless document model. Remaining
transformations outside the parser grammar are:

- Applying the LaTeX commands from `@preamble`s entries to other entries
- Optional transformation of Unicode <-> LaTeX characters

### CFF

The CFF importer validates version 1.2 documents against the bundled official
JSON Schema before projecting their metadata.
