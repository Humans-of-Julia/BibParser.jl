module BibTeX

import DataStructures: OrderedDict
import BibInternal
import BibParser: occurs_in

export parse_string
export parse_document

"""
    mutable struct Accumulator

A structure to accumulate part of the input stream as a simple string. It differs from Position that store `line` and `column` information.
"""
mutable struct Accumulator
    from::Int
    to::Int
end

"""
    Content

Store the different BibTeX elements once successfully parsed.

!!! warning "Note:"
    Free text, comments entries and preambles entries are currently ignored.
"""
struct Content
    # comments::Dict{Int, String}
    entries::OrderedDict{String, BibInternal.Entry}
    # free::Dict{Int, String}
    # preambles::Dict{Int, String}
    strings::Dict{String, String}
end

"""
    Content()

Create an (almost) empty content constructor for a new `Parser`. Some usual BibTeX content is added:
- List of months abbreviations in English (added automatically by some BibTeX class)

Feel free to contribute to more default content.
"""
function Content()
    # comments = Dict{Int, String}()
    entries = OrderedDict{String, BibInternal.Entry}()
    # free = Dict{Int, String}()
    # preambles = Dict{Int, String}()
    strings = Dict{String, String}([
        "jan" => "January",
        "feb" => "February",
        "mar" => "March",
        "apr" => "April",
        "may" => "May",
        "jun" => "June",
        "jul" => "July",
        "aug" => "August",
        "sep" => "September",
        "oct" => "October",
        "nov" => "November",
        "dec" => "December"
    ])
    return Content(entries, strings)
end

"""
    Field

A structure that can store BibTeX fields information.

# Arguments:
- `braces::Int`: counter to the number of opened braces in a field being parsed
- `name::String`: name of the field being parsed
- `quotes::Bool`: `true` if the field is delimited by quotes
- `value::String`: the value of the field
"""
mutable struct Field
    braces::Int
    name::String
    quotes::Bool
    value::String

    Field() = new(0, "", false, "")
end

"""
    Position

A structure pointing to a position in the input based on rows and columns.
"""
mutable struct Position
    row::Int
    col::Int
end

"""
    Position()

Initial position constructor
"""
Position() = Position(0, 0)

"""
    Storage

Store the content of an entry being parsed.

# Arguments:
- `delim::Union{Char, Nothing}`: the character delimiting the entry
- `fields::Vector{Field}`: a collection of the entry's fields
- `key::String`: the key of the entry
- `kind::String`: the kind/type of BibTeX entry
"""
mutable struct Storage
    delim::Union{Char, Nothing}
    fields::Vector{Field}
    key::String
    kind::String
end

"""
    Storage()
Empty storage constructor called when a new entry is being parsed.
"""
Storage() = Storage(nothing, Vector{Field}(), "", "")

"""
    make_entry(storage)

Make a `BibInternal.Entry` from a completed entry in a parser storage.
"""
function make_entry(storage)
    d = Dict("_type" => storage.kind)
    foreach(field -> push!(d, field.name => field.value), storage.fields)
    return d
end

"""
    BibTeXError

Description of a BibTeXError, including the relevant position in the input string.

# Arguments:
- `kind::Symbol`: the type of BibTeX error
- `input::String`: the BibTeX string being parsed
- `start::Position`: the row/col start position of the BibTeXError
- `stop::Position`: the row/col end position of the BibTeXError
"""
struct BibTeXError
    kind::Symbol
    input::String
    start::Position
    stop::Position

    BibTeXError(k, i, sta, sto) = new(k, "'" * strip(i) * "'", deepcopy(sta), deepcopy(sto))
end

function warn(error, ::Val)
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The entry kind is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_string})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The string entry is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:incomplete_entry})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The entry is incomplete and end from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_key})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The entry key is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_name})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The field name is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_number})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The field value has an invalid format (number) from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_var})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    return str = "The field value has an invalid format (string variable) from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

"""
    warn(error)

Dispatch a BibTeX error as a Julia warning based on the type of error.
"""
warn(error) = @warn warn(error, Val(error.kind))

"""
    Parser

A structure allowing to parse a BibTeX formatted string one character at a time.

# Arguments:
- `acc::Accumulator`: an accumulated string from last `dump` to `content`
- `content::Content`: the current content of a parser
- `errors::Vector{BibTeXError}`: a collection of BibTeX errors
- `field::Field`: temporary storage for an entry fields names
- `input::Vector{Char}`: the BibTeX string
- `pos_start::Position`: pointer to the raw/col start position
- `pos_end::Position`: pointer to the raw/col end position
- `storage::Storage`: temporary storage of the content of an entry being parsed
- `rules_checker::Bool`: indicate which level `:error`, `:warn`, or `:none` should be raised when an entry violates BibTeX rules
- `format::Symbol`: bibliography ruleset used for canonical entry construction
- `task::Symbol`: describe which part of the BibTeX gramma is being parsed
"""
mutable struct Parser
    acc::Accumulator
    content::Content
    errors::Vector{BibTeXError}
    field::Field
    input::Vector{Char}
    pos_start::Position
    pos_end::Position
    rules_checker::Symbol
    format::Symbol
    storage::Storage
    task::Symbol

    function Parser(
            input;
            acc = Accumulator(1, 0),
            content = Content(),
            errors = Vector{BibTeXError}(),
            field = Field(),
            pos_start = Position(1, 1),
            pos_end = Position(1, 0),
            rules_checker = :error,
            format = :BibTeX,
            storage = Storage(),
            task = :free
    )
        return new(
            acc,
            content,
            errors,
            field,
            collect(input),
            pos_start,
            pos_end,
            rules_checker,
            format,
            storage,
            task
        )
    end
end

"""
    rev(char)

Return the closing character `)`/`}` matching either `(` or `{`.
"""
rev(char) = char == '(' ? ')' : '}'

"""
    get_entries(parser)

Retrieve the entries successfully parsed by `parser`.
"""
get_entries(parser) = parser.content.entries

"""
    finalize_entry!(parser)

Finalize the current parsed entry and store it in parser content.
Duplicate keys are handled according to parser `rules_checker`:
- `:error`: throw an error
- `:warn`: emit a warning and keep first occurrence
- `:none`: silently keep first occurrence
"""
function finalize_entry!(parser)
    key = parser.storage.key
    check = parser.rules_checker
    if haskey(parser.content.entries, key)
        if check == :error
            error("Duplicate BibTeX entry key detected: '$key'")
        elseif check == :warn
            @warn "Duplicate BibTeX entry key detected: '$key'. Keeping first entry."
        end
    else
        entry = make_entry(parser.storage)
        bibentry = parser.format == :BibLaTeX ?
                   BibInternal.make_biblatex_entry(key, entry; check) :
                   BibInternal.make_bibtex_entry(key, entry; check)
        push!(parser.content.entries, key => bibentry)
    end
    parser.storage = Storage()
    parser.task = :free
    return nothing
end

"""
    get_acc(parser; from = 1, to = 0)

Retrieve the `Accumulator` of the parser.

# Arguments:
- `parser`: a `Parser`
- `from`: a positive offset from the start of the `Accumulator`, default to `1`
- `to`:  a negative offset from the end of the `Accumulator`, default to `0`
"""
function get_acc(parser; from = 1, to = 0)
    a = from + parser.acc.from - 1
    b = parser.acc.to - to
    return prod(parser.input[a:b])
end

"""
    set_delim!(parser, char)

Set the delimiter for this section of the entry to parenthesis or braces.
"""
set_delim!(parser, char) = parser.storage.delim = char

"""
    set_entry_kind!(parser, kind) = begin

Set the kind of the entry being parsed in the `parser`'s storage.
"""
set_entry_kind!(parser, kind) = parser.storage.kind = kind

"""
    inc_col!(parser) = begin

Increment the `column` field of the pointer to the end position of the Parser.
"""
inc_col!(parser) = parser.pos_end.col += 1

"""
    inc_row!(parser)

Increment the `row` field of the pointer to the end position of the Parser.
"""
function inc_row!(parser)
    parser.pos_end.row += 1
    return parser.pos_end.col = 1
end

"""
    inc!(parser, char, dumped)

Increment the start/end position and accumulator of the parser.

# Arguments:
- `parser`: a `BibTeX.Parser` structure
- `char`: the character being parsed
- `dumped`: boolean value describing if the `Accumulator` content is being dumped into the parser `Content`
"""
function inc!(parser, char, dumped)
    char == '\n' ? inc_row!(parser) : inc_col!(parser)
    parser.acc.to += 1
    if dumped
        parser.pos_start = deepcopy(parser.pos_end)
        parser.acc.from = parser.acc.to
    end
end

is_dumped(::Parser, char, ::Val{:free}) = char == '@'
dump!(parser, char, ::Val) = char == '@' && (parser.task = :entry)

is_dumped(::Parser, char, ::Val{:entry}) = occurs_in(r"[@{\(\n]", char)
function dump!(parser, char, ::Val{:entry})
    if char == '\n'
        parser.task = :free
        e = BibTeXError(:invalid_kind, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
        parser.storage = Storage()
    elseif char ∈ ['{', '(']
        set_delim!(parser, char)
        acc = split(lowercase(get_acc(parser; from = 2)), r"[\t ]+")
        if length(acc) ≤ 1 && !isempty(acc[1])
            set_entry_kind!(parser, acc[1])
            if acc[1] == "string"
                parser.task = :string
            elseif acc[1] ∈ ["comment", "preamble"]
                parser.field.braces = 1
                parser.task = :special
            else
                parser.task = :key
            end
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_kind, get_acc(parser), parser.pos_start, parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(::Parser, char, ::Val{:key}) = char ∈ ['@', ',']
function dump!(parser, char, ::Val{:key})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == ','
        acc = split(get_acc(parser; from = 2), r"[\t ]+")
        if length(acc) ≤ 1 && !isempty(acc[1])
            parser.storage.key = acc[1]
            parser.task = :field_name
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_key, get_acc(parser; from = 2), parser.pos_start, parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(::Parser, char, ::Val{:field_name}) = char ∈ ['=', '@']
function dump!(parser, char, ::Val{:field_name})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty = false)
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :field_in
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_field_name,
                get_acc(parser; from = 2),
                parser.pos_start,
                parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(::Parser, char, ::Val{:field_in}) = occurs_in(r"[0-9@a-zA-Z\"{]", char)
function dump!(parser, char, ::Val{:field_in})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '"'
        parser.pos_start.col += 1
        parser.acc.from += 1
        parser.task = :field_inquote
    elseif char == '{'
        parser.task = :field_inbrace
        parser.field.braces += 1
    elseif occurs_in(r"[0-9]", char)
        parser.task = :field_number
    elseif occurs_in(r"[a-zA-Z]", char)
        parser.task = :field_var
    end
end

function is_dumped(parser, char, ::Val{:field_inbrace})
    if char == '{'
        parser.field.braces += 1
        return false
    elseif char == '}'
        parser.field.braces -= 1
        return (parser.field.braces == 0)
    elseif char == '@'
        return true
    else
        return false
    end
end
function dump!(parser, char, ::Val{:field_inbrace})
    if char == '@'
        parser.task = :entry
        parser.field.braces = 0
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '}'
        parser.field.value *= get_acc(parser; from = 2)
        push!(parser.storage.fields, deepcopy(parser.field))
        parser.field.value = ""
        parser.task = :field_out
    end
end

is_dumped(::Parser, char, ::Val{:field_inquote}) = char ∈ ['{', '"', '}']
function dump!(parser, char, ::Val{:field_inquote})
    if char == '"' && parser.field.braces == 0
        parser.field.value *= get_acc(parser; from = 2)
        parser.task = :field_outquote
    elseif char == '{'
        parser.field.value *= get_acc(parser; from = 2) # * parser.field.value
        parser.field.braces += 1
    elseif char == '}'
        parser.field.value *= get_acc(parser; from = 1, to = -1) # * parser.field.value
        parser.field.braces -= 1
    end
end

function is_dumped(parser, char, ::Val{:field_outquote})
    return char ∈ ['@', ',', '#', rev(parser.storage.delim)]
end
function dump!(parser, char, ::Val{:field_outquote})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '#'
        parser.task = :field_concat
    else
        push!(parser.storage.fields, deepcopy(parser.field))
        parser.field.value = ""
        if char == ','
            parser.task = :field_next
        elseif char == rev(parser.storage.delim)
            finalize_entry!(parser)
        end
    end
end

is_dumped(::Parser, char, ::Val{:field_concat}) = occurs_in(r"[a-zA-Z\"@]", char)
function dump!(parser, char, ::Val{:field_concat})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '"'
        parser.pos_start.col += 1
        parser.acc.from += 1
        parser.task = :field_inquote
    elseif occurs_in(r"[a-zA-Z]", char)
        parser.task = :field_var
    end
end

function is_dumped(parser, char, ::Val{:field_var})
    return char ∈ ['@', ',', '#', rev(parser.storage.delim)]
end
function dump!(parser, char, ::Val{:field_var})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    else
        acc = split(get_acc(parser), r"[\t\r\n ]+"; keepempty = false)
        if length(acc) == 1
            parser.field.value *= parser.content.strings[acc[1]]
            if char == '#'
                parser.task = :field_concat
            else
                push!(parser.storage.fields, deepcopy(parser.field))
                parser.field.value = ""
                if char == ','
                    parser.task = :field_next
                elseif char == rev(parser.storage.delim)
                    finalize_entry!(parser)
                end
            end
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_field_var, get_acc(parser), parser.pos_start, parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:field_number}) = char ∈ ['@', ',', rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_number})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    else
        acc = split(get_acc(parser), r"[\t\r\n ]+"; keepempty = false)
        # @show acc
        if length(acc) == 1
            parser.field.value = acc[1]
            push!(parser.storage.fields, deepcopy(parser.field))
            parser.field.value = ""
            if char == ','
                parser.task = :field_next
            elseif char == rev(parser.storage.delim)
                finalize_entry!(parser)
            end
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_field_number, get_acc(parser), parser.pos_start, parser.pos_end
            )
            push!(parser.errors, e)
        end
    end
end

is_dumped(parser, char, ::Val{:field_out}) = char ∈ ['@', ',', rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_out})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == ','
        parser.task = :field_next
    elseif char == rev(parser.storage.delim)
        finalize_entry!(parser)
    end
end

is_dumped(parser, char, ::Val{:field_next}) = char ∈ ['=', '@', rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_next})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty = false)
        # @show acc
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :field_in
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_field_name, get_acc(parser), parser.pos_start, parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    elseif char == rev(parser.storage.delim)
        finalize_entry!(parser)
    end
end

function is_dumped(parser, char, ::Val{:special})
    if char == parser.storage.delim
        parser.field.braces += 1
        return false
    elseif char == rev(parser.storage.delim)
        parser.field.braces -= 1
        return parser.field.braces == 0
    else
        return false
    end
end
function dump!(parser, char, ::Val{:special})
    if char == rev(parser.storage.delim)
        parser.field = Field()
        parser.storage = Storage()
        parser.task = :free
    end
end

is_dumped(::Parser, char, ::Val{:string}) = char ∈ ['=', '@']
function dump!(parser, char, ::Val{:string})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty = false)
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :string_inquote
        else
            parser.task = :free
            e = BibTeXError(
                :invalid_string,
                get_acc(parser; from = 2, to = -1),
                parser.pos_start,
                parser.pos_end
            )
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(::Parser, char, ::Val{:string_inquote}) = char ∈ ['"', '@']
function dump!(parser, char, ::Val{:string_inquote})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == '"'
        parser.task = :string_value
    end
end

is_dumped(::Parser, char, ::Val{:string_value}) = char ∈ ['"']
function dump!(parser, char, ::Val{:string_value})
    if char == '"'
        parser.field.value = get_acc(parser; from = 2)
        parser.task = :string_outquote
    end
end

is_dumped(parser, char, ::Val{:string_outquote}) = char ∈ [rev(parser.storage.delim), '@']
function dump!(parser, char, ::Val{:string_outquote})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(
            :incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end
        )
        push!(parser.errors, e)
    elseif char == rev(parser.storage.delim)
        parser.content.strings[parser.field.name] = parser.field.value
        parser.field = Field()
        parser.task = :free
        parser.storage = Storage()
    end
end

"""
    is_dumped(parser, char)

Check if an `Accumulator` needs to be `dump!`ed. Dispatch to the appropriate `is_dumped` method according to the state of the parser.
"""
is_dumped(parser, char) = is_dumped(parser, char, Val(parser.task))

"""
    dump!(parser, char = ' ')

Dump the content of the parser `Accumulator` into the parser `Content`. Dispatch to the appropriate `dump!` method according to the state of the parser.
"""
function dump!(parser, char = ' ')
    dump!(parser, char, Val(parser.task))
    parser.pos_start = deepcopy(parser.pos_end)
    return parser.acc.from = parser.acc.to
end

"""
    parse!(parser, char)

Parse a single character of a BibTeX string. Modify the `Parser` accordingly.
"""
function parse!(parser, char)
    dumped = is_dumped(parser, char)
    dumped && dump!(parser, char)
    return inc!(parser, char, dumped)
end

"""
    parse_string(str)

Parse a BibTeX string of entries. Raise a detailed warning for each invalid entry.
"""
function parse_string(str; check = :error, format = :BibTeX)
    parser = Parser(str; rules_checker = check, format)
    foreach(char -> parse!(parser, char), parser.input)
    foreach(error -> warn(error), parser.errors)
    return get_entries(parser)
end

"""
    parse_file(path)

Parse a BibTeX file located at `path`. Raise a detailed warning for each invalid entry.
"""
parse_file(path; check = :error, format = :BibTeX) = parse_string(read(path, String); check, format)

function _source_span(input::String, start::Int, stop::Int)
    prefix = start == firstindex(input) ? "" : input[firstindex(input):prevind(input, start)]
    body = input[start:stop]
    start_line = count(==('\n'), prefix) + 1
    last_newline = findlast(==('\n'), prefix)
    start_column = isnothing(last_newline) ? length(prefix) + 1 :
                   length(prefix[nextind(prefix, last_newline):end]) + 1
    end_line = start_line + count(==('\n'), body)
    body_newline = findlast(==('\n'), body)
    end_column = isnothing(body_newline) ? start_column + length(body) - 1 :
                 length(body[nextind(body, body_newline):end]) + 1
    return BibInternal.SourceSpan(
        start_line = start_line,
        start_column = start_column,
        end_line = end_line,
        end_column = end_column,
    )
end

function _entry_end(input::String, open_index::Int, open_char::Char)
    close_char = rev(open_char)
    depth = 1
    inquote = false
    escaped = false
    index = nextind(input, open_index)
    while index <= lastindex(input)
        char = input[index]
        if char == '"' && !escaped
            inquote = !inquote
        elseif !inquote && char == open_char
            depth += 1
        elseif !inquote && char == close_char
            depth -= 1
            depth == 0 && return index
        end
        escaped = char == '\\' && !escaped
        char == '\\' || (escaped = false)
        index = nextind(input, index)
    end
    return lastindex(input)
end

function _header(raw::String)
    m = match(r"(?is)^\s*@\s*([A-Za-z]+)\s*([\{\(])", raw)
    isnothing(m) && return "", nothing
    return lowercase(m.captures[1]), only(m.captures[2])
end

function _body(raw::String)
    kind, open_char = _header(raw)
    isempty(kind) && return ""
    start = findfirst(open_char, raw)
    isnothing(start) && return ""
    stop = findlast(rev(open_char), raw)
    isnothing(stop) || stop <= start ? "" : raw[nextind(raw, start):prevind(raw, stop)]
end

function _entry_key(raw::String)
    body = _body(raw)
    comma = findfirst(==(','), body)
    isnothing(comma) && return strip(body)
    return strip(body[begin:prevind(body, comma)])
end

function _field_chunks(body::AbstractString)
    chunks = String[]
    start = firstindex(body)
    depth = 0
    inquote = false
    escaped = false
    for index in eachindex(body)
        char = body[index]
        if char == '"' && !escaped
            inquote = !inquote
        elseif !inquote && char in ['{', '(']
            depth += 1
        elseif !inquote && char in ['}', ')']
            depth = max(depth - 1, 0)
        elseif !inquote && depth == 0 && char == ','
            push!(chunks, body[start:prevind(body, index)])
            start = nextind(body, index)
        end
        escaped = char == '\\' && !escaped
        char == '\\' || (escaped = false)
    end
    start <= lastindex(body) && push!(chunks, body[start:end])
    return chunks
end

function _raw_fields(raw::String)
    body = _body(raw)
    comma = findfirst(==(','), body)
    isnothing(comma) && return BibInternal.RawField[]
    field_body = strip(body[nextind(body, comma):end])
    raw_fields = BibInternal.RawField[]
    for chunk in _field_chunks(field_body)
        stripped = strip(chunk)
        isempty(stripped) && continue
        eq = findfirst(==('='), stripped)
        isnothing(eq) && continue
        name = strip(stripped[begin:prevind(stripped, eq)])
        value = strip(stripped[nextind(stripped, eq):end])
        if !isempty(value) && first(value) in ['{', '"'] && last(value) in ['}', '"']
            value = value[nextind(value, firstindex(value)):prevind(value, lastindex(value))]
        end
        push!(raw_fields, BibInternal.RawField(name = name, value = value, raw = stripped))
    end
    return raw_fields
end

function _block_kind(kind::String)
    kind == "string" && return :string
    kind == "comment" && return :comment
    kind == "preamble" && return :preamble
    return :entry
end

function parse_document(input::String; check = :error, format::Symbol = :BibTeX)
    entries = BibInternal.LosslessEntry[]
    blocks = BibInternal.RawBlock[]
    diagnostics = BibInternal.Diagnostic[]
    parsed_entries = parse_string(input; check, format)
    cursor = firstindex(input)
    while cursor <= lastindex(input)
        at = findnext(==('@'), input, cursor)
        if isnothing(at)
            raw = input[cursor:end]
            isempty(strip(raw)) || push!(blocks, BibInternal.RawBlock(kind = :free, raw = raw))
            break
        end
        if at > cursor
            raw = input[cursor:prevind(input, at)]
            isempty(strip(raw)) || push!(
                blocks,
                BibInternal.RawBlock(
                    kind = :free,
                    raw = raw,
                    span = _source_span(input, cursor, prevind(input, at))
                )
            )
        end
        open_at = findnext(c -> c in ['{', '('], input, at)
        if isnothing(open_at)
            raw = input[at:end]
            push!(blocks, BibInternal.RawBlock(kind = :free, raw = raw, span = _source_span(input, at, lastindex(input))))
            break
        end
        stop = _entry_end(input, open_at, input[open_at])
        raw = input[at:stop]
        kind, _ = _header(raw)
        block_kind = _block_kind(kind)
        span = _source_span(input, at, stop)
        if block_kind == :entry
            try
                key = _entry_key(raw)
                entry = get(parsed_entries, key, nothing)
                if !isnothing(entry)
                    raw_entry = BibInternal.RawEntry(
                        kind = kind,
                        key = key,
                        fields = _raw_fields(raw),
                        raw = raw,
                        span = span,
                    )
                    push!(entries, BibInternal.LosslessEntry(entry, raw_entry))
                end
            catch err
                diagnostic = BibInternal.Diagnostic(
                    code = :parse_error,
                    severity = BibInternal.diagnostic_error,
                    message = sprint(showerror, err),
                    span = span,
                    entry_id = _entry_key(raw),
                    suggestion = "Fix the BibTeX entry or parse with a more permissive check level."
                )
                push!(diagnostics, diagnostic)
                check == :error && rethrow()
            end
        else
            push!(
                blocks,
                BibInternal.RawBlock(
                    kind = block_kind,
                    key = kind == "string" ? _entry_key(raw) : "",
                    raw = raw,
                    span = span,
                )
            )
        end
        cursor = nextind(input, stop)
    end
    return BibInternal.BibliographyDocument(
        format = format,
        entries = entries,
        blocks = blocks,
        diagnostics = diagnostics,
    )
end

end # module
