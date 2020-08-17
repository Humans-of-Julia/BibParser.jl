module BibParser

export parse_file

# BibTeX module
include("bibtex.jl")
import .BibTeX

# CSL-JSON module
include("csl.jl")
import .CSL

"""
    parse_file(path::String; parser::Symbol = :BibTeX)
Parse a bibliography file. Default to BibTeX format. No other options available yet (CSL-JSON coming soon).
"""
function parse_file(path::String; parser::Symbol = :BibTeX)
    if parser == :BibTeX
        BibTeX.parse_file(path)
    end
end

include("precompile.jl")
_precompile_()

end # module
