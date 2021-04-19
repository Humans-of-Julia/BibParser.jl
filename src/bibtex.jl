module BibTeX

using DataStructures
using BibInternal

export parse_string

mutable struct Accumulator
    from::Int
    to::Int
end

struct Content
    # comments::Dict{Int, String}
    entries::OrderedDict{String,BibInternal.Entry}
    # free::Dict{Int, String}
    # preambles::Dict{Int, String}
    strings::Dict{String,String}
end

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

mutable struct Field
    braces::Int
    name::String
    quotes::Bool
    value::String

    Field() = new(0, "", false, "")
end


mutable struct Position
    row::Int
    col::Int
end

Position() = Position(0, 0)

mutable struct Storage
    delim::Union{Char,Nothing}
    fields::Vector{Field}
    key::String
    kind::String
end

Storage() = Storage(nothing, Vector{Field}(), "", "")

function make_entry(storage)
    # @info "making entry" storage
    d = Dict("_type" => storage.kind)
    foreach(field -> push!(d, field.name => field.value), storage.fields)
    return d
end

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

warn(error) = @warn warn(error, Val(error.kind))

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

rev(char) = char == '(' ? ')' : '}'

get_entries(parser) = parser.content.entries
function get_acc(parser; from = 1, to = 0)
    a = from + parser.acc.from - 1
    b = parser.acc.to - to
    return prod(parser.input[a:b])
end

set_delim!(parser, char) = parser.storage.delim = char
set_entry_kind!(parser, kind) = parser.storage.kind = kind

inc_col!(t) = t.pos_end.col += 1
function inc_row!(t)
    t.pos_end.row += 1
    t.pos_end.col = 1
end

function inc!(t, char, dumped)
    char == '\n' ? inc_row!(t) : inc_col!(t)
    t.acc.to += 1
    if dumped
        t.pos_start = deepcopy(t.pos_end)
        t.acc.from = t.acc.to
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
    elseif occursin(r"[0-9]", char)
        parser.task = :field_number
    elseif occursin(r"[a-zA-Z]", char)
        parser.task = :field_var
    end
end

is_dumped(parser, char, ::Val{:field_inbrace}) = char ∈ ['@', '{', '}']
function dump!(parser, char, ::Val{:field_inbrace})
    if char == '@'
        parser.task = :entry
        e = BibTeXError(:incomplete_entry, get_acc(parser), parser.pos_start, parser.pos_end)
        push!(parser.errors, e)
    elseif char == '}' && parser.field.braces == 0
        parser.field.value *= get_acc(parser; from = 2)
        push!(parser.storage.fields, deepcopy(parser.field))
        parser.field.value = ""
        parser.task = :field_out
    elseif char == '{'
        parser.field.value *= get_acc(parser; from = 2) # * parser.field.value
        parser.field.braces += 1
    elseif char == '}'
        parser.field.value *= get_acc(parser; from = 1, to = -1) # * parser.field.value
        parser.field.braces -= 1
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
            # @info "Printing" parser.content.strings[acc[1]] parser.field.value
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
                    parser.task = :free
                end
            end
        else
            parser.task = :free
            e = BibTeXError(:invalid_field_var, get_acc(parser), parser.pos_start, parser.pos_end)
            push!(parser.errors, e)
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
        # @show entry
        push!(parser.content.entries,
            parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
        )
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
        end
    elseif char == rev(parser.storage.delim)
        entry = make_entry(parser.storage)
        push!(parser.content.entries,
            parser.storage.key => BibInternal.make_bibtex_entry(parser.storage.key, entry)
        )
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
    end
end

is_dumped(parser, char) = is_dumped(parser, char, Val(parser.task))

function dump!(parser, char=' ')
    dump!(parser, char, Val(parser.task))
    parser.pos_start = deepcopy(parser.pos_end)
    parser.acc.from = parser.acc.to
end

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

function parse_string(str, ::Val{:bibtex})
    parser = Parser(str)
    foreach(char -> parse!(parser, char), parser.input)
    foreach(error -> warn(error), parser.errors)
    # @info "Dev: " parser
    return get_entries(parser)
end

function parse_file(path::String)
    entries = parse_string(read(path, String), Val(:bibtex))
    return entries
end

end # module
