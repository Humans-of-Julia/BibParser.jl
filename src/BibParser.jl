"""
BibParser converts bibliography source formats into BibInternal data.

The package focuses on parsing only. Use `parse_entry` and `parse_file` for the
legacy entry dictionary workflow, or `parse_bibliography` when you want a
lossless `BibInternal.BibliographyDocument`.
"""
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

# RIS module
include("ris.jl")
using .RIS: RIS

"""
    parse_file(path::String, parser::Symbol = :BibTeX; check=:error)

Parse a bibliography file and return the legacy entry representation.

The default parser is `:BibTeX`. Use `:BibLaTeX` or `:RIS` directly in the
core package, and install the relevant extensions to enable the other formats.
For bibliography formats with validation rules, `check` can be `:none`,
`nothing`, `:warn`, or `:error`.
"""
parse_file(path, ::Val{:BibTeX}; check) = BibTeX.parse_file(path; check)
function parse_file(path, ::Val{:BibLaTeX}; check)
    BibTeX.parse_file(path; check, format = :BibLaTeX)
end
parse_file(path, ::Val{:RIS}; check) = RIS.parse_document(read(path, String)).entries

parse_file(path, parser = :BibTeX; check = :error) = parse_file(path, Val(parser); check)

"""
    parse_string(input::String; format::Symbol = :BibTeX, check = :error)

Parse bibliography content from a string and return entries in the legacy
format. Prefer [`parse_bibliography`](@ref) when source preservation and
diagnostics are needed.
"""
parse_string(input; format::Symbol = :BibTeX, check = :error) = parse_file(
    IOBuffer(input), Val(format); check)

parse_file(io::IO, ::Val{:BibTeX}; check) = BibTeX.parse_string(read(io, String); check)
function parse_file(io::IO, ::Val{:BibLaTeX}; check)
    BibTeX.parse_string(read(io, String); check, format = :BibLaTeX)
end

"""
    parse_bibliography(input; format::Symbol = :auto, check = :error)

Parse a bibliography and return a `BibInternal.BibliographyDocument`
preserving raw source blocks where the parser supports lossless mode.
"""
function parse_bibliography(input; format::Symbol = :auto, check = :error)
    detected = format == :auto ? detect_format(input) : format
    return parse_bibliography(input, Val(detected); check)
end

function parse_bibliography(input, ::Val{:BibTeX}; check = :error)
    BibTeX.parse_document(_read_input(input); check, format = :BibTeX)
end

function parse_bibliography(input, ::Val{:BibLaTeX}; check = :error)
    BibTeX.parse_document(_read_input(input); check, format = :BibLaTeX)
end

function parse_bibliography(input, ::Val{:RIS}; check = :error)
    RIS.parse_document(_read_input(input))
end

function parse_file(path, ::Val{format}; check) where {format}
    throw(ArgumentError("The $format parser extension is not loaded."))
end

function parse_bibliography(input, ::Val{format}; check = :error) where {format}
    throw(ArgumentError("The $format parser extension is not loaded."))
end

"""
    parse_entry(entry::String; parser::Symbol = :BibTeX, check = :error)

Parse a single BibTeX entry string using the legacy parser.

For bibliography formats with validation rules, the `check` keyword argument
can be set to `:none`, `nothing`, `:warn`, or `:error`.
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

"""
    detect_format(input)

Best-effort format detection used by `parse_bibliography` when `format = :auto`.
"""
function detect_format(input)
    content = strip(_read_input(input))
    isempty(content) && return :BibTeX
    startswith(content, "@") && return :BibTeX
    (startswith(content, "{") || startswith(content, "[")) && return :CSL
    occursin("cff-version:", content) && return :CFF
    occursin(r"(?m)^\s*TY  - ?", content) && return :RIS
    startswith(content, "<") && return detect_xml_format(content)
    return :BibTeX
end

"""
    detect_xml_format(content::AbstractString)

Heuristic XML format detection used by the parser extensions.
"""
function detect_xml_format(content::AbstractString)
    occursin(r"<\s*(records?|rec-number|ref-type)\b", content) && return :EndNote
    return :MODS
end

end # module
