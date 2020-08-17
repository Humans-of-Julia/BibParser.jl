using Documenter, BibParser, BibInternal

makedocs(
    sitename = "BibParser.jl",
    authors = "Jean-François BAFFIER",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "BibParser" => "index.md",
        "BibTeX" => "bibtex.md",
        "BibTeX - automa" => "bibtex_automa.md",
        "CSL-JSON" => "csl.md",
        "Internal" => "internal.md",
    ]
)

deploydocs(
    repo = "github.com/Azzaare/BibParser.jl.git"
)
