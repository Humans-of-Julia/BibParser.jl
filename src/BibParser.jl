module BibParser

export parse_entry
export parse_file

include("utils.jl")

# BibTeX module
include("bibtex.jl")
using .BibTeX: BibTeX

# CSL-JSON module
include("csl.jl")
using .CSL: CSL

# CFF module
include("cff.jl")
using .CFF: CFF

"""
    parse_file(path::String, parser::Symbol = :BibTeX; check=:error)
Parse a bibliography file. Default to BibTeX format. Other options available: CFF (CSL-JSON coming soon).
For bibliography formats with formatting rules (such as `:BibTeX`), the `check` keyword argument can be set to `:none` (or `nothing`), `:warn`, or `:error`.
"""
parse_file(path, ::Val{:BibTeX}; check) = BibTeX.parse_file(path; check)
parse_file(path, ::Val{:CFF}; check) = CFF.parse_file(path)

parse_file(path, parser=:BibTeX; check=:error) = parse_file(path, Val(parser); check)

"""
    parse_entry(entry::String; parser::Symbol = :BibTeX, check = :error)
Parse a string entry. Default to BibTeX format. No other options available yet (CSL-JSON coming soon).

For bibliography formats with formatting rules (such as `:BibTeX`), the `check` keyword argument can be set to `:none` (or `nothing`), `:warn`, or `:error`.
"""
function parse_entry(entry; parser=:BibTeX, check = :error)
    return parser == :BibTeX && return BibTeX.parse_string(entry; check)
end

end # module
