module BibParser

export parse_entry
export parse_file

include("utils.jl")

# BibTeX module
include("bibtex.jl")
import .BibTeX

# CSL-JSON module
include("csl.jl")
import .CSL

# CFF module
include("cff.jl")
import .CFF

"""
    parse_file(path::String; parser::Symbol = :BibTeX)
Parse a bibliography file. Default to BibTeX format. No other options available yet (CSL-JSON coming soon).
"""
function parse_file(path; parser=:BibTeX)
    parser == :BibTeX && return BibTeX.parse_file(path)
    parser == :CFF && return CFF.parse_file(path)
end


"""
    parse_entry(entry::String; parser::Symbol = :BibTeX)
Parse a string entry. Default to BibTeX format. No other options available yet (CSL-JSON coming soon).
"""
function parse_entry(entry; parser=:BibTeX)
    return parser == :BibTeX && return BibTeX.parse_string(entry)
end

end # module
