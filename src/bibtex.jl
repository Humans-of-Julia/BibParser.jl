module BibTeX

# Import Automa.jl package to create the Finite-State Machine of the BibTeX grammar
import Automa
import Automa.RegExp: @re_str

import DataStructures
import DataStructures.OrderedSet

using BibInternal, BibInternal.BibTeX

export parse, parse_file

# Define the notation for RegExp in Automa.jl
const re = Automa.RegExp

# Concatenation with spaces: \times (tab completion)
× = (x::re.RE, y::re.RE) -> x * re.rep(re"[\t\n\r ]") * y

const machine = (
    function () # Grammar
    # Basic regexp
    publication_type    = re"@[A-Za-z]+"
    field_name          = re"[A-Za-z]+"
    in_braces           = re"[^@{}]"
    in_quotes           = re"[^\"]"
    key                 = re"[A-Za-z][0-9A-Za-z_:/]*"
    left_brace          = re"{"
    number              = re"[0-9]+"
    quotes              = re"\""
    right_brace         = re"}"
    space               = re"[\t\n\r ]"

    # Complex regexp
    brace_value     = left_brace * re.rep(in_braces | left_brace | right_brace) * right_brace
    quote_value     = quotes * re.rep(brace_value | in_quotes) * quotes
    value           = number | quote_value | brace_value
    field_value     = re.rep(value × re"#") × value    
    field           = field_name × re"=" × field_value
    fields          = re.rep(re"," × field)    
    entry_content   = key × fields × re.opt(re",")
    brace_entry     = left_brace × entry_content × right_brace
    publication     = publication_type × brace_entry 
    bibliography    = re.rep(space | publication)


    # RegExp/States Actions
    brace_value.actions[:enter]         = [:brace_in]
    brace_value.actions[:exit]          = [:brace_out, :brace_value]
    # field.actions[:enter]               = [:print_info]
    # field.actions[:exit]                = [:print_field]    
    field.actions[:exit]                = [:add_field]
    field_name.actions[:enter]          = [:mark_in]
    field_name.actions[:exit]           = [:mark_out, :field_name]
    field_value.actions[:enter]         = [:clean_field]
    key.actions[:enter]                 = [:mark_in]
    key.actions[:exit]                  = [:mark_out, :key]
    left_brace.actions[:exit]           = [:inc_braces]
    number.actions[:enter]              = [:number_in]
    number.actions[:exit]               = [:number_out, :number_value]
    publication.actions[:enter]         = [:clean_entry]
    publication.actions[:exit]          = [:add_entry]
    publication_type.actions[:enter]    = [:mark_in]
    publication_type.actions[:exit]     = [:mark_out, :publication_type]
    quote_value.actions[:enter]         = [:quote_in]
    quote_value.actions[:exit]          = [:quote_out, :quote_value]
    quotes.actions[:enter]              = [:in_quotes]
    right_brace.actions[:enter]         = [:dec_braces]
    value.actions[:enter]               = [:clean_counters]

    return Automa.compile(bibliography)
end
)()

# Generate actions for the FSM
const bibtex_actions = Dict(
    :add_entry          => :(entries[key] = BibInternal.BibTeX.make_bibtex_entry(publication_type, key, fields)),
    :add_field          => :(fields[field_name] = value),
    :brace_in           => :(brace_in = p),
    :brace_out          => :(brace_out = p),
    :brace_value        => :(in_braces == 0 && !in_quotes ? value *= data[brace_in + 1:brace_out - 2] : ()),
    :clean_counters     => :(in_quotes ? () : in_braces = 0),
    :clean_field        => :(value = ""),
    :clean_entry        => :(fields = Dict{String,String}()),
    :dec_braces         => :(in_braces -= 1),
    :field_name         => :(field_name = lowercase(data[mark_in:mark_out - 1])),
    :in_quotes          => :(in_braces == 0 ? in_quotes = !in_quotes : ()),
    :inc_braces         => :(in_braces += 1),
    :key                => :(key = data[mark_in:mark_out - 1]),
    :mark_in            => :(mark_in = p),
    :mark_out           => :(mark_out = p),
    :number_in          => :(number_in = p),
    :number_out         => :(number_out = p),
    :number_value       => :(value *= data[number_in:number_out - 1]),
    # TODO: why is the value == "" necessary (debug)
    # TODO: bug with }} when the second brace is to close the entry
    # :print_field        => :(println(value == "" ? "field: $field_name = \"\"" : "field: $field_name = $value")),
    # :print_info         => :(println("info: $(data[1:p - 1])")),
    :publication_type   => :(publication_type = lowercase(data[mark_in + 1:mark_out - 1])),
    :quote_in           => :(quote_in = p),
    :quote_out          => :(quote_out = p),
    :quote_value        => :(in_braces == 0 ? value *= data[quote_in + 1:quote_out - 2] : ()),
)

const context = Automa.CodeGenContext()

@eval function parse(data::String)
    # Variables to store data
    entries          = DataStructures.OrderedDict{String, BibInternal.AbstractEntry}()
    fields           = Dict{String,String}()
    field_name       = ""
    key              = ""
    publication_type = ""
    value            = ""

    # Marks where to extract strings 
    mark_in          = 0
    mark_out         = 0
    brace_in         = 0
    brace_out        = 0
    quote_in         = 0
    quote_out        = 0
    number_in        = 0
    number_out       = 0

    # Counting braces, and marking in quotes field values
    in_quotes        = false
    in_braces        = 0 # left braces increment by one, right ones decrement

    # generate code to initialize variables used by FSM
    $(Automa.generate_init_code(context, machine))

    # set end and EOF positions of data buffer
    p_end = p_eof = sizeof(data)

    # generate code to execute FSM
    $(Automa.generate_exec_code(context, machine, bibtex_actions))

    # check if FSM properly finished and returm the state of the FSM
    return entries, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
end

function parse_file(path::String)
    return parse(open(x -> read(x, String), path))
end

end