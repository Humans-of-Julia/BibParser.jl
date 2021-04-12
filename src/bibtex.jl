module BibTeX

using CombinedParsers
using CombinedParsers.Regexp
using TextParse

# Concatenation with spaces: \times (tab completion)
× = (x, y) -> x * Repeat(re"[\t\n\r ]") * y

# Basic regexp
publication_type = re"@[a-z]+"i
field_name = re"[a-z]+"i
in_braces = re"[^@{}]"
in_quotes = re"[^\"]"
key = re"[a-z][0-9a-z_:/\-\\]*"i
left_brace = re"\{"
number = re"[0-9]+"
quotes = re"\""
right_brace = re"\}"
space = re"[\t\n\r ]"

# Complex regexp
brace_value = left_brace * Repeat(in_braces | left_brace | right_brace) * right_brace
quote_value = quotes * Repeat(brace_value | in_quotes) * quotes
value = number | quote_value | brace_value
field_value = Repeat(value × re"#") × value
field = field_name × re"=" × field_value
fields = Repeat(re"," × field)
entry_content = key × fields × Optional(re",")
brace_entry = left_brace × entry_content × right_brace
publication = publication_type × brace_entry
bibliography = Repeat(space | publication)

@enum Kind begin
    AT # '@'
    COMA # ','
    QUOTE # '"'
    LEFT_BRACE # '{'
    RIGHT_BRACE # '}'
    LEFT_PARENTHESIS # '('
    RIGHT_PARENTHESIS # ')'
    CONCAT # '#'
    NEW_LINE # '\n' # TODO: is \r useful?

    ENTRY # for error log
    PREAMBLE # preamble entry
    COMMENT_ENTRY # comment entry
    STRING_ENTRY # string entry
    COMMENT_TEXT # free text
    PUBLICATION # type of a publication

    KEY # article key
    FIELD_NAME # field name
    FIELD_VALUE # field value (quoted, braced, number, or var_string)
end

struct Token
    kind::Kind
    # Offsets into a string or buffer
    startpos::Tuple{Int, Int} # row, col where token starts /end, col is a string index
    endpos::Tuple{Int, Int}
    # startbyte::Int # The byte where the token start in the buffer
    # endbyte::Int # The byte where the token ended in the buffer
    val::String # The actual string of the token
    # token_error::TokenError
    # dotop::Bool
    # suffix::Bool
    delim::Union{Char, Nothing}
end

mutable struct Tokenizer
    tokens::Vector{Token}
    acc::String
    startpos::Tuple{Int, Int}
    endpos::Tuple{Int, Int}
    row::Int
    col::Int
    delim::Union{Char, Nothing}
    counter::Int
    level::Symbol
    parent_level::Symbol
    vars::Dict{String, String}
end

function Token(t, kind; delim = nothing)
    Token(kind, get_start(t), get_end(t), get_acc(t), delim)
end

get_tokens(t) = t.tokens
get_acc(t) = t.acc
get_start(t) = t.startpos
get_end(t) = t.endpos
get_row(t) = t.row
get_col(t) = t.col
get_delim(t) = t.delim
get_count(t) = t.counter
get_level(t) = t.level
get_parent(t) = t.parent_level

inc_acc!(t, char) = t.acc *= char
reset_acc!(t) = t.acc = ""
set_start!(t, startpos) = t.startpos = startpos
set_end!(t, endpos) = t.endpos = endpos
function inc_row!(t)
    t.row += 1
    t.col = 1
end
inc_col!(t) = t.col += 1
set_delim!(t, char) = t.delim = char
inc_count!(t) = t.counter += 1
dec_count!(t) = t.counter -= 1
set_level!(t, level) = t.level = level
set_parent!(t, level) = t.parent_level = level
reset_parent!(t) = set_parent!(t, :top)

is_acc_empty(t) = isempty(get_acc(t))

Base.push!(t::Tokenizer, token) = push!(get_tokens(t), token)

function tokenize!(t, char, ::Val{:preamble})
    set_level!(t, :value)
    set_parent!(t, :preamble)
    push!(t, Token(PREAMBLE, t; delim = get_delim(t)))
    tokenize!(t, char, Val(:value))
end

function tokenize!(t, char, ::Val{:comment})
    if char ∉ [get_delim(t), '@']
        inc_acc!(t, char)
    else
        if char == '@'
            push!(t, Token(COMMENT_TEXT, t))
            set_level!(t, :entry)
        else
            push!(t, Token(COMMENT_ENTRY, t))
            set_level!(t, :free)
        end
        reset_acc!(t)
        set_start!(t, (row, col))
        set_parent!(t, :top)
    end
end

function tokenize!(t, char, ::Val{:entry})
    if char ∈ ['(', '{'] && !is_acc_empty(t)
        _type = lowercase(get_acc(t))
        push!(t, Token(ENTRY, t; delim = '{'))
        reset_acc!(t)
        set_start!(t, (row, col))
        set_level!(t, _type ∈ ["comment", "preamble", "string"] ? Symbol(_type) : :key)
        set_parent!(t, _type ∈ ["comment", "preamble", "string"] ? Symbol(_type) : :entry)
        set_delim!(t, char)
    elseif occursin(r"[a-zA-Z]+", string(char))
        inc_acc!(t, char)
    else
        set_level!(t, :free)
        @warn "Error: uncorrect entry type at line $row character $col in the entry starting at line $(startpos[1]) character $(startpos[2])."
    end
end

function tokenize!(t, char, ::Val{:free})
    if char != '@'
        inc_acc!(t, char)
    else
        push!(t, Token(COMMENT_TEXT, t))
        reset_acc!(t)
        set_start!(t, (row, col))
        set_level!(t, :entry)
    end
end

function inc!(t, char)
    set_end!(t, (get_row(t), get_col(t)))
    char == '\n' ? inc_row!(t) : inc_col!(t)
end

function tokenize!(t, char)
    inc!(t, char)
    tokenize!(t, char, Val(get_level(t)))
end

function tokenize(str)
    t = Tokenizer(
        Vector{Token}(),
        "", # character accumulator
        (1, 1), # start position
        (0, 0), # end position (non init)
        row, # row
        col, # column
        delim, # entry delimiter
        counter, # brace counter
        :free, # start at free text level
        :top, # parent level of :free is :top
        Dict{String, String}()
    )
    foreach(char -> tokenize!(t, char), str)
    get_level(t) == :free && push!(get_tokens(t), Token(COMMENT_TEXT, t))
    return tokens
end

end