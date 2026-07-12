```@contents
```

BibParser supports CSL-JSON through the `JSON3` extension. This parser maps
CSL records onto the canonical `BibInternal.Entry` model and keeps the original
JSON payload in the lossless document view.

```julia
using BibParser, JSON3

document = parse_bibliography(read("references.json", String); format = :CSL)
```
