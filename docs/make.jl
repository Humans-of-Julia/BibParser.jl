using Documenter, BibParser, BibInternal

makedocs(
    sitename = "BibParser.jl",
    authors = "Jean-François BAFFIER",
    repo="https://github.com/Humans-of-Julia/BibParser.jl/blob/{commit}{path}#L{line}",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "BibParser" => "index.md",
        "BibTeX" => "bibtex.md",
        # "BibTeX - automa" => "bibtex_automa.md",
        "CSL-JSON" => "csl.md",
        "Internal" => "internal.md",
    ]
)

deploydocs(; repo = "github.com/Humans-of-Julia/BibParser.jl.git", devbranch = "master")
