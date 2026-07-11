module RIS

import BibInternal

const RIS_TO_BIBTEX_TYPES = Dict{String, String}(
    "JOUR" => "article",
    "MGZN" => "article",
    "NEWS" => "article",
    "BOOK" => "book",
    "EBOOK" => "book",
    "CHAP" => "incollection",
    "ECHAP" => "incollection",
    "CONF" => "inproceedings",
    "CPAPER" => "inproceedings",
    "RPRT" => "techreport",
    "THES" => "phdthesis",
    "UNPB" => "unpublished",
    "ELEC" => "misc",
    "GEN" => "misc"
)

function _push_tag!(records, current, tag, value)
    tag == "TY" && isempty(current) || tag == "TY" || !isempty(current) || return current
    if tag == "TY" && !isempty(current)
        push!(records, current)
        current = Dict{String, Vector{String}}()
    end
    push!(get!(current, tag, String[]), value)
    if tag == "ER"
        push!(records, current)
        current = Dict{String, Vector{String}}()
    end
    return current
end

function parse_records(input::String)
    records = Vector{Dict{String, Vector{String}}}()
    current = Dict{String, Vector{String}}()
    last_tag = ""
    for line in split(input, '\n')
        isempty(strip(line)) && continue
        m = match(r"^\s*([A-Z0-9]{2})  - ?(.*)$", line)
        if isnothing(m)
            if !isempty(last_tag)
                current[last_tag][end] *= "\n" * strip(line)
            end
            continue
        end
        tag = something(m.captures[1], "")
        value = something(m.captures[2], "")
        current = _push_tag!(records, current, tag, strip(value))
        last_tag = tag == "ER" ? "" : tag
    end
    isempty(current) || push!(records, current)
    return records
end

_first(record, tags...; default = "") = begin
    for tag in tags
        values = get(record, tag, String[])
        isempty(values) || return first(values)
    end
    return default
end

function _names(values)
    return map(values) do value
        try
            BibInternal.Name(value)
        catch
            parts = split(value, ","; limit = 2)
            if length(parts) == 2
                BibInternal.Name("", strip(parts[1]), "", strip(parts[2]), "")
            else
                BibInternal.Name("", strip(value), "", "", "")
            end
        end
    end
end

function _date(record)
    year = _first(record, "PY", "Y1", "Y2")
    m = match(r"(\d{4})(?:/(\d{1,2}))?(?:/(\d{1,2}))?", year)
    isnothing(m) && return BibInternal.Date("", "", year)
    return BibInternal.Date(
        something(m.captures[3], ""),
        something(m.captures[2], ""),
        something(m.captures[1], "")
    )
end

function _pages(record)
    pages = _first(record, "SP")
    ep = _first(record, "EP")
    isempty(ep) && return pages
    isempty(pages) && return ep
    return pages * "--" * ep
end

function parse_entry(record)
    ris_type = _first(record, "TY"; default = "GEN")
    type = get(RIS_TO_BIBTEX_TYPES, ris_type, "misc")
    id = _first(record, "ID", "DO")
    title = _first(record, "TI", "T1", "CT")
    isempty(id) && (id = replace(lowercase(title), r"[^a-z0-9]+" => "-"))
    authors = _names(vcat(get(record, "AU", String[]), get(record, "A1", String[])))
    editors = _names(get(record, "ED", String[]))
    access = BibInternal.Access(_first(record, "DO"), "", _first(record, "UR"))
    date = _date(record)
    booktitle = _first(record, "BT", "T2")
    in_ = BibInternal.In(
        _first(record, "CY"),
        "",
        _first(record, "ET"),
        _first(record, "PB"),
        _first(record, "SN"),
        _first(record, "SN"),
        _first(record, "JO", "JF", "JA", "T2"),
        _first(record, "IS"),
        "",
        _pages(record),
        _first(record, "PB"),
        "",
        "",
        _first(record, "VL")
    )
    fields = Dict(
        "ris:" * lowercase(tag) => join(values, "\n") for (tag, values) in record
    )
    note = _first(record, "N1", "AB")
    eprint = BibInternal.Eprint("", "", "")
    return BibInternal.Entry(access, authors, booktitle, date, editors,
        eprint, id, in_, fields, note, title, type)
end

function parse_document(input::String)
    diagnostics = BibInternal.Diagnostic[]
    try
        entries = BibInternal.LosslessEntry[]
        for record in parse_records(input)
            haskey(record, "TY") || continue
            entry = parse_entry(record)
            raw = BibInternal.RawEntry(kind = "ris",
                key = entry.id,
                raw = join(
                    vcat([tag * "  - " * value for (tag, values) in record
                          for value in values]),
                    "\n"))
            push!(entries, BibInternal.LosslessEntry(entry, raw))
        end
        return BibInternal.BibliographyDocument(
            format = :RIS, entries = entries, source = input)
    catch err
        push!(
            diagnostics,
            BibInternal.Diagnostic(
                code = :parse_error,
                severity = BibInternal.diagnostic_error,
                message = sprint(showerror, err),
                suggestion = "Fix the RIS record."
            )
        )
    end
    return BibInternal.BibliographyDocument(
        format = :RIS, diagnostics = diagnostics, source = input)
end

end
