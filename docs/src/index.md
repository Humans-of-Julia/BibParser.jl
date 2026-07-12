BibParser turns bibliographic source text into canonical bibliography entries or
lossless bibliography documents.

Use it when you need parsing only. Use `Bibliography.jl` when you want the
full import/export workflow.

Supported formats:

- BibTeX and BibLaTeX in the core package;
- RIS in the core package;
- CFF 1.2 through the `YAML` and `JSONSchema` extensions;
- CSL-JSON through the `JSON3` extension;
- EndNote XML and MODS through the `EzXML` extension.

The lossless document parser keeps raw blocks, source spans, and diagnostics
when the backend format makes that possible.

```julia
using BibParser

entries = parse_file("references.bib")
document = parse_bibliography("references.bib"; format = :BibTeX)
```

```@contents
```

```@autodocs
Modules = [BibParser]
Pages   = ["BibParser.jl"]
```
