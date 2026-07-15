using Documenter, BibParser, BibInternal

makedocs(
    sitename = "BibParser.jl",
    authors = "Jean-François BAFFIER",
    format = Documenter.HTML(
        prettyurls = true,
        canonical = "https://juliabibliographies.github.io/BibParser.jl",
        edit_link = "master"
    ),
    pages = [
        "BibParser" => "index.md",
        "BibTeX" => "bibtex.md",
        # "BibTeX - automa" => "bibtex_automa.md",
        "CSL-JSON" => "csl.md",
        "Internal" => "internal.md"
    ]
)

deploydocs(; repo = "github.com/JuliaBibliographies/BibParser.jl.git", devbranch = "master")
