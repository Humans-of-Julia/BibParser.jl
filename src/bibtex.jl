# Concatenation with spaces: \times (tab completion)
× = (x::re.RE, y::re.RE)->x * re.rep(re"[\t\n\r ]") * y

# Finite-State Machine (FSM) for the BibTeX language
const bibtex_machine = (
    function ()
    # Bib grammar (slightly simplified)
    # TODO: doc the simplified bib grammar
    space               = re"[\t\n\r ]"
    field_name          = re"[A-Za-z]+"
    number              = re"[0-9]+"
    in_quote            = !re"[\"{}]"
    in_braces           = !re"[@{}]"
    left_brace          = re"{"
    right_brace         = re"}"
    key                 = re"[A-Za-z][0-9A-Za-z_:/]*"
    publication_type    = re"[A-Za-z]+"

    # TODO: .when field for brace values
    brace_value     = re"{" * re.rep(in_braces | left_brace | right_brace) * re"}"
    quote_value     = re"\"" * re.rep(brace_value | in_quote) * re"\""
    value           = number | quote_value | brace_value
    # field_value     = re.rep(value × re"#") × value
    field           = field_name × re"=" × value
    fields          = re.rep(re"," × field)
    entry_content   = key × fields × re.opt(re",")
    brace_entry     = re"{" × entry_content × re"}"
    publication     = re"@" * publication_type × brace_entry
    bibliography    = re.rep(space | publication)

    # Conditional actions
    # brace_value.when = :condition

    # RegExp/States Actions
    brace_value.actions[:enter]         = [:mark_in]
    brace_value.actions[:exit]          = [:mark_out, :value]
    field.actions[:exit]                = [:add_field]
    field_name.actions[:enter]          = [:mark_in]
    field_name.actions[:exit]           = [:mark_out, :field_name]
    key.actions[:enter]                 = [:mark_in]
    key.actions[:exit]                  = [:mark_out, :key]
    left_brace.actions[:exit]           = [:count_in]
    number.actions[:enter]              = [:mark_in]
    number.actions[:exit]               = [:mark_out, :number]
    publication.actions[:enter]         = [:clean_fields]
    publication.actions[:exit]          = [:add_entry]
    publication_type.actions[:enter]    = [:mark_in]
    publication_type.actions[:exit]     = [:mark_out, :publication_type]
    quote_value.actions[:enter]         = [:mark_in]
    quote_value.actions[:exit]          = [:mark_out, :value]
    right_brace.actions[:enter]         = [:count_out]

    return Automa.compile(bibliography)
end)()

# Generate actions for the FSM
const bibtex_actions = Dict(
    :add_entry        => :(entries[key] = Entry(Symbol(publication_type), key, fields)),
    :add_field        => :(fields[Symbol(field_name)] = value),
    # :cat_quote        => :(value *= data[mark_in + 1:mark_out - 2]),
    # :cat_var          => :(value *= strings[search_name]),
    :clean_fields     => :(fields = BibInternal.EntryFields()),
    :condition        => :(acc == 0),
    :count_in         => :(acc += 1),
    :count_out        => :(acc -= 1),
    # :empty_string     => :(value = ""),
    :field_name       => :(field_name = lowercase(data[mark_in:mark_out - 1])),
    :key              => :(key = data[mark_in:mark_out - 1]),
    :mark_in          => :(mark_in = p),
    :mark_out         => :(mark_out = p),
    :number           => :(value = data[mark_in:mark_out - 1]),
    :publication_type => :(publication_type = lowercase(data[mark_in:mark_out - 2])),
    # :search_name      => :(search_name = lowercase(data[mark_in:mark_out - 1])),
    :value            => :(value = data[mark_in + 1:mark_out - 2]))

const context = Automa.CodeGenContext()

@eval function parsebib(data::AbstractString)
    # initialize the variables to store the parsed code
    entries          = Dict{AbstractString,BibInternal.Entry}()
    # strings          = Dict{AbstractString,AbstractString}()
    fields           = BibInternal.EntryFields()
    publication_type = ""
    key              = ""
    field_name       = ""
    value            = ""
    # search_name = ""
    mark_in          = 0
    mark_out         = 0
    acc              = 0

    # generate code to initialize variables used by FSM
    $(Automa.generate_init_code(context, bibtex_machine))

    # set end and EOF positions of data buffer
    p_end = p_eof = sizeof(data)

    # generate code to execute FSM
    $(Automa.generate_exec_code(context, bibtex_machine, bibtex_actions))

    # check if FSM properly finished and returm the state of the FSM
    return entries, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
end

function parsebibfile(path::AbstractString)
    return parsebib(open(x->read(x, String), path))
end




