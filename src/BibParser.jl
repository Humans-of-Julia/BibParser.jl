module BibParser

export parse_file



# BibTeX module
include("bibtex.jl")

import .BibTeXParser

function parse_file(path::String; parser::Symbol = :BibTeX)
    BibTeXParser.parse_bibtex_file(path)
end

include("precompile.jl")
_precompile_()

end # module
