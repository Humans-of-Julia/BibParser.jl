# Finite-State Machine (FSM) for the BibTeX language
const bibmachine = (function ()
    # Bib grammar
    spaces = re.rep(re"[\t ]+" | re"\r?\n")
    numvalue = re"[0-9]+"
    varname = re"[A-Za-z][0-9A-Za-z]*"
    prequote = re.rep(varname * spaces * re"#" * spaces)
    postquote = re.rep(spaces * re"#" * spaces * varname)
    inquote1 = re"\"[^\"]*\""
    inquotedfield = re.alt(varname, inquote1)
    quotedfield = re.rep(inquotedfield * spaces * re"#" * spaces) * inquotedfield
    inbrace = re"{[^}]*}"
    fieldvalue = numvalue | inbrace | quotedfield
    fieldname = re"[A-Za-z]+"
    field = fieldname * spaces * re"=" * spaces * fieldvalue * spaces
    fields = re.rep(re"," * spaces * field) * re.opt(re",") * spaces
    key = re"[A-Za-z][0-9A-Za-z]*"
    inpublication = key * spaces * fields

    inquote2 = re"\"[^\"]*\""
    strname = re"[A-Za-z][0-9A-Za-z]*"
    instring = spaces * strname * spaces * re"=" * spaces * inquote2 * spaces

    publitype = re"[A-Za-z]+{"
    publication = publitype * inpublication
    comment  = re"[cC][oO][mM][mM][eE][nN][tT]{[^}]*"
    string   = re"[sS][tT][rR][iI][nN][gG]{" * instring
    preamble = re"[pP][rR][eE][aA][mM][bB][lL][eE]{[^}]*"

    entry = preamble | comment | string | publication

    nonentry = re"[^@]+"
    bibfile = re.rep(nonentry | re.cat(re"@", entry, re"}"))


    # RegExp/States Actions for string entries and conversion
    string.actions[:exit]           = [:addstring]
    strname.actions[:enter]         = [:markin]
    strname.actions[:exit]          = [:markout, :name]
    inquote2.actions[:enter]        = [:markin]
    inquote2.actions[:exit]         = [:markout, :stringvalue]

    # RegExp/States Actions for string conversion in quoted field
    quotedfield.actions[:enter]     = [:emptystring]
    inquote1.actions[:enter]        = [:markin]
    inquote1.actions[:exit]         = [:markout, :catquote]
    varname.actions[:enter]         = [:markin]
    varname.actions[:exit]          = [:markout, :searchname, :catvar]

    # RegExp/States Actions for publication entries
    publication.actions[:exit]      = [:addentry]
    publitype.actions[:enter]       = [:markin]
    publitype.actions[:exit]        = [:markout, :publitype]
    key.actions[:enter]             = [:markin]
    key.actions[:exit]              = [:markout, :key]
    fieldname.actions[:enter]       = [:markin]
    fieldname.actions[:exit]        = [:markout, :name]
    numvalue.actions[:enter]        = [:markin]
    numvalue.actions[:exit]         = [:markout, :numvalue]
    inbrace.actions[:enter]         = [:markin]
    inbrace.actions[:exit]          = [:markout, :stringvalue]
    field.actions[:exit]            = [:addfield]

    return Automa.compile(bibfile)
end)()

# Generate actions for the FSM
bibactions = Dict(
    :addentry           => :(entries[key] = Entry(publitype, key, fields)),
    :addfield           => :(fields[Symbol(name)] = value),
    :addstring          => :(strings[name] = value),
    :catquote           => :(value *= data[markin + 1:markout - 2]),
    :catvar             => :(value *= strings[searchname]),
    :emptystring        => :(value = ""),
    :key                => :(key = data[markin:markout - 1]),
    :markin             => :(markin = p),
    :markout            => :(markout = p),
    :name               => :(name = lowercase(data[markin:markout - 1])),
    :numvalue           => :(value = data[markin:markout - 1]),
    :publitype          => :(publitype = lowercase(data[markin:markout - 2])),
    :searchname         => :(searchname = lowercase(data[markin:markout - 1])),
    :stringvalue        => :(value = data[markin + 1:markout - 2]))

context = Automa.CodeGenContext()
@eval function parsebib(data::AbstractString)
    # initialize the variables to store the parsed code
    entries     = Dict{AbstractString,Entry}()
    strings     = Dict{AbstractString,AbstractString}()
    fields      = EntryFields()
    publitype   = key       = name      = value     = searchname    = ""
    markin      = markout   = 0

    # generate code to initialize variables used by FSM
    $(Automa.generate_init_code(context, bibmachine))

    # set end and EOF positions of data buffer
    p_end = p_eof = sizeof(data)

    # generate code to execute FSM
    $(Automa.generate_exec_code(context, bibmachine, bibactions))

    # check if FSM properly finished and returm the state of the FSM
    return entries, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
end

function parsebibfile(path::AbstractString)
    return parsebib(open(x->read(x, String), path))
end