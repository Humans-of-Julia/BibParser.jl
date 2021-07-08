module BibTeX

using DataStructures
using BibInternal

export parse_string

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

Store the different BibTeX elements once succesfully parsed.

!!! warning "Note:"
    Free text, comments entries and preambles entries are currently ignored.
"""
struct Content
    # comments::Dict{Int, String}
    entries::OrderedDict{String,BibInternal.Entry}
    # free::Dict{Int, String}
    # preambles::Dict{Int, String}
    strings::Dict{String,String}
end

"""
    Content()

Create an (almost) empty content constructor for a new `Parser`. Some usual BibTeX content is added:
- List of months abbreviations in English (added automatically by some BibTeX class)

Feel free to contribute to more default content.
"""
function Content()
    # comments = Dict{Int, String}()
    entries = OrderedDict{String,BibInternal.Entry}()
    # free = Dict{Int, String}()
    # preambles = Dict{Int, String}()
    strings = Dict{String,String}([
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
        "dec" => "December",
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
    delim::Union{Char,Nothing}
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
    str = "The entry kind is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_string})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The string entry is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:incomplete_entry})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The entry is incomplete and end from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_key})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The entry key is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_name})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The field name is invalid from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_number})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The field value has an invalid format (number) from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
end

function warn(error, ::Val{:invalid_field_var})
    row_start, col_start = error.start.row, error.start.col
    row_stop, col_stop = error.stop.row, error.stop.col
    str = "The field value has an invalid format (string variable) from (line $row_start, character $col_start) to (line $row_stop, character $col_stop): $(error.input)"
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
    storage::Storage
    task::Symbol

    function Parser(input;
        acc=Accumulator(1, 0),
        content=Content(),
        errors=Vector{BibTeXError}(),
        field=Field(),
        pos_start=Position(1, 1),
        pos_end=Position(1, 0),
        storage=Storage(),
        task=:free,
    )
        new(acc, content, errors, field, collect(input), pos_start, pos_end, storage, task)
    end
end

"""
    rev(char)

Return the closing character `)`/`}` matching either `(` or `{`.
"""
rev(char) = char == '(' ? ')' : '}'

"""
    get_entries(parser)

Retrieve the entries succesfully parsed by `parser`.
"""
get_entries(parser) = parser.content.entries

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
    parser.pos_end.col = 1
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

is_dumped(parser, char, ::Val{:free}) = char == '@'
dump!(parser, char, ::Val) = char == '@' && (parser.task = :entry)

is_dumped(parser, char, ::Val{:entry}) = occursin(r"[@{\(\n]", char)
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
            # parser.task = acc[1] ∈ ["comment", "preamble", "string"] ? Symbol(acc[1]) : :key
            parser.task = acc[1] ∈ ["string"] ? Symbol(acc[1]) : :key
        else
            parser.task = :free
            e = BibTeXError(:invalid_kind, get_acc(parser), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:key}) = char ∈ ['@', ',']
function dump!(parser, char, ::Val{:key})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == ','
        acc = split(get_acc(parser; from = 2), r"[\t ]+")
        if length(acc) ≤ 1 && !isempty(acc[1])
            parser.storage.key = acc[1]
            parser.task = :field_name
        else
            parser.task = :free
            e = BibTeXError(:invalid_key, get_acc(parser;from = 2), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:field_name}) = char ∈ ['=', '@']
function dump!(parser, char, ::Val{:field_name})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty=false)
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :field_in
        else
            parser.task = :free
            e = BibTeXError(:invalid_field_name, get_acc(parser; from = 2), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:field_in}) = occursin(r"[0-9@a-zA-Z\"{]", char)
function dump!(parser, char, ::Val{:field_in})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '"'
        parser.pos_start.col += 1
        parser.acc.from += 1
        parser.task = :field_inquote
    elseif char == '{'
        parser.task = :field_inbrace
        parser.field.braces += 1
    elseif occursin(r"[0-9]", char)
        parser.task = :field_number
    elseif occursin(r"[a-zA-Z]", char)
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
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '}'
        parser.field.value *= get_acc(parser; from = 2)
        push!(parser.storage.fields, deepcopy(parser.field))
        parser.field.value = ""
        parser.task = :field_out
    end
end

is_dumped(parser, char, ::Val{:field_inquote}) = char ∈ ['{', '"', '}']
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
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '#'
        parser.task = :field_concat
    else
        push!(parser.storage.fields, deepcopy(parser.field))
        parser.field.value = ""
        if char == ','
            parser.task = :field_next
        elseif char == rev(parser.storage.delim)
            entry = make_entry(parser.storage)
            push!(parser.content.entries,
            parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
            )
            parser.storage = Storage()
            parser.task = :free
        end
    end
end

is_dumped(parser, char, ::Val{:field_concat}) = occursin(r"[a-zA-Z\"@]", char)
function dump!(parser, char, ::Val{:field_concat})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '"'
        parser.pos_start.col += 1
        parser.acc.from += 1
        parser.task = :field_inquote
    elseif occursin(r"[a-zA-Z]", char)
        parser.task = :field_var
    end
end

function is_dumped(parser, char, ::Val{:field_var})
    return char ∈ ['@', ',', '#', rev(parser.storage.delim)]
end
function dump!(parser, char, ::Val{:field_var})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    else
        acc = split(get_acc(parser), r"[\t\r\n ]+"; keepempty=false)
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
                    entry = make_entry(parser.storage)
                    push!(parser.content.entries, parser.storage.key =>
                        BibInternal.make_bibtex_entry(parser.storage.key, entry)
                    )
                    parser.storage = Storage()
                    parser.task = :free
                end
            end
        else
            parser.task = :free
            e = BibTeXError(:invalid_field_var, get_acc(parser), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:field_number}) = char ∈ ['@', ',',rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_number})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    else
        acc = split(get_acc(parser), r"[\t\r\n ]+"; keepempty=false)
        # @show acc
        if length(acc) == 1
            parser.field.value = acc[1]
            push!(parser.storage.fields, deepcopy(parser.field))
            parser.field.value = ""
            if char == ','
                parser.task = :field_next
            elseif char == rev(parser.storage.delim)
                entry = make_entry(parser.storage)
                push!(parser.content.entries,
                parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
                )
                parser.task = :free
            end
        else
            parser.task = :free
            e = BibTeXError(:invalid_field_number, get_acc(parser), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
        end
    end
end

is_dumped(parser, char, ::Val{:field_out}) = char ∈ ['@', ',', rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_out})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == ','
        parser.task = :field_next
    elseif char == rev(parser.storage.delim)
        entry = make_entry(parser.storage)
        push!(parser.content.entries,
            parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
        )
        parser.storage = Storage()
        parser.task = :free
    end
end

is_dumped(parser, char, ::Val{:field_next}) = char ∈ ['=', '@', rev(parser.storage.delim)]
function dump!(parser, char, ::Val{:field_next})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty=false)
        # @show acc
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :field_in
        else
            parser.task = :free
            e = BibTeXError(:invalid_field_name, get_acc(parser), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    elseif char == rev(parser.storage.delim)
        entry = make_entry(parser.storage)
        push!(parser.content.entries,
            parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
        )
        parser.storage = Storage()
        parser.task = :free
    end
end

is_dumped(parser, char, ::Val{:string}) = char ∈ ['=', '@']
function dump!(parser, char, ::Val{:string})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '='
        acc = split(get_acc(parser; from = 2), r"[\t\r\n ]+"; keepempty=false)
        if length(acc) == 1
            parser.field.name = acc[1]
            parser.task = :string_inquote
        else
            parser.task = :free
            e = BibTeXError(:invalid_string, get_acc(parser; from = 2, to = -1), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
            parser.storage = Storage()
        end
    end
end

is_dumped(parser, char, ::Val{:string_inquote}) = char ∈ ['"', '@']
function dump!(parser, char, ::Val{:string_inquote})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '"'
        parser.task = :string_value
    end
end

is_dumped(parser, char, ::Val{:string_value}) = char ∈ ['"']
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
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == rev(parser.storage.delim)
        parser.content.strings[parser.field.name] = parser.field.value
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
function dump!(parser, char=' ')
    dump!(parser, char, Val(parser.task))
    parser.pos_start = deepcopy(parser.pos_end)
    parser.acc.from = parser.acc.to
end

"""
    parse!(parser, char)

Parse a single character of a BibTeX string. Modify the `Parser` accordingly.
"""
function parse!(parser, char)
    dumped = is_dumped(parser, char)
    dumped && dump!(parser, char)
    inc!(parser, char, dumped)
    # fieldout = parser.task == :field_out
    # dumped && @info parser parser char dumped
    # dumped && @warn parser.acc parser.content parser.field parser.input parser.pos_start parser.pos_end parser.storage parser.task
    # @info parser parser char dumped
    # @warn parser.acc parser.content parser.field parser.input parser.pos_start parser.pos_end parser.storage parser.task
end

"""
    parse_string(str)

Parse a BibTeX string of entries. Raise a detailed warning for each invalid entry.
"""
function parse_string(str)
    parser = Parser(str)
    foreach(char -> parse!(parser, char), parser.input)
    foreach(error -> warn(error), parser.errors)
    return get_entries(parser)
end

"""
    parse_file(path)

Parse a BibTeX file located at `path`. Raise a detailed warning for each invalid entry.
"""
parse_file(path) = parse_string(read(path, String))

end # module
