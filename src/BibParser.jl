module BibParser

export parse_file

# BibTeX module
include("bibtex.jl")
import .BibTeX

# CSL-JSON module
include("csl.jl")
import .CSL

function parse_file(path::String; parser::Symbol = :BibTeX)
    if parser == :BibTeX
        BibTeX.parse_file(path)
    end
end

include("precompile.jl")
_precompile_()

end # module
