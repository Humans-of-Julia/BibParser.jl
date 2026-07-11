module BibParser

import TestItems: @testitem

export parse_entry
export parse_file
export parse_bibliography
export parse_string

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
parse_file(path, ::Val{:BibLaTeX}; check) = BibTeX.parse_file(path; check = :none)
parse_file(path, ::Val{:CFF}; check) = CFF.parse_file(path)

parse_file(path, parser = :BibTeX; check = :error) = parse_file(path, Val(parser); check)

"""
    parse_string(input::String; format::Symbol = :BibTeX, check = :error)

Parse bibliography content from a string and return entries in the legacy
format. Prefer [`parse_bibliography`](@ref) when source preservation and
diagnostics are needed.
"""
parse_string(input; format::Symbol = :BibTeX, check = :error) =
    parse_file(IOBuffer(input), Val(format); check)

parse_file(io::IO, ::Val{:BibTeX}; check) = BibTeX.parse_string(read(io, String); check)
parse_file(io::IO, ::Val{:BibLaTeX}; check) = BibTeX.parse_string(read(io, String); check = :none)

"""
    parse_bibliography(input; format::Symbol = :auto, check = :error)

Parse a bibliography and return a `BibInternal.BibliographyDocument` preserving
raw source blocks where the parser supports lossless mode.
"""
function parse_bibliography(input; format::Symbol = :auto, check = :error)
    detected = format == :auto ? detect_format(input) : format
    return parse_bibliography(input, Val(detected); check)
end

parse_bibliography(input, ::Val{:BibTeX}; check = :error) =
    BibTeX.parse_document(_read_input(input); check, format = :BibTeX)

parse_bibliography(input, ::Val{:BibLaTeX}; check = :error) =
    BibTeX.parse_document(_read_input(input); check = :none, format = :BibLaTeX)

parse_bibliography(input, ::Val{:CFF}; check = :error) =
    CFF.parse_document(_read_input(input))

"""
    parse_entry(entry::String; parser::Symbol = :BibTeX, check = :error)
Parse a string entry. Default to BibTeX format. No other options available yet (CSL-JSON coming soon).

For bibliography formats with formatting rules (such as `:BibTeX`), the `check` keyword argument can be set to `:none` (or `nothing`), `:warn`, or `:error`.
"""
function parse_entry(entry; parser = :BibTeX, check = :error)
    return parser == :BibTeX && return BibTeX.parse_string(entry; check)
end

function _read_input(input)
    if input isa IO
        return read(input, String)
    elseif input isa AbstractString && isfile(input)
        return read(input, String)
    else
        return String(input)
    end
end

function detect_format(input)
    content = strip(_read_input(input))
    isempty(content) && return :BibTeX
    startswith(content, "@") && return :BibTeX
    (startswith(content, "{") || startswith(content, "[")) && return :CSL
    occursin("cff-version:", content) && return :CFF
    occursin(r"(?m)^TY  - ", content) && return :RIS
    startswith(content, "<") && return :MODS
    return :BibTeX
end

end # module
