module CSL

import BibInternal
import JSON3

function _string(value, default = "")
    value === nothing && return default
    return string(value)
end

function _names(values)
    isnothing(values) && return BibInternal.Name[]
    return map(values) do person
        literal = get(person, :literal, nothing)
        if !isnothing(literal)
            BibInternal.Name("", _string(literal), "", "", "")
        else
            BibInternal.Name(
                get(person, Symbol("non-dropping-particle"),
                    get(person, :non_dropping_particle, "")),
                get(person, :family, ""),
                get(person, :suffix, ""),
                get(person, :given, ""),
                ""
            )
        end
    end
end

function _date(value)
    isnothing(value) && return BibInternal.Date("", "", "")
    parts = get(value, Symbol("date-parts"), nothing)
    if !isnothing(parts) && !isempty(parts) && !isempty(parts[1])
        row = parts[1]
        year = length(row) >= 1 ? string(row[1]) : ""
        month = length(row) >= 2 ? string(row[2]) : ""
        day = length(row) >= 3 ? string(row[3]) : ""
        return BibInternal.Date(day, month, year)
    end
    raw = get(value, :raw, "")
    return BibInternal.Date("", "", string(raw))
end

const CSL_TO_BIBTEX_TYPES = Dict{String, String}(
    "article" => "article",
    "article-journal" => "article",
    "article-magazine" => "article",
    "article-newspaper" => "article",
    "book" => "book",
    "classic" => "book",
    "collection" => "book",
    "chapter" => "incollection",
    "entry" => "incollection",
    "entry-dictionary" => "incollection",
    "entry-encyclopedia" => "incollection",
    "manuscript" => "unpublished",
    "pamphlet" => "booklet",
    "paper-conference" => "inproceedings",
    "report" => "techreport",
    "thesis" => "phdthesis",
    "webpage" => "misc"
)

function _fields(item)
    fields = Dict{String, String}()
    for (key, value) in pairs(item)
        fields[string(key)] = if value === nothing
            ""
        elseif value isa AbstractString || value isa Number || value isa Bool
            string(value)
        else
            JSON3.write(value)
        end
    end
    return fields
end

function parse_entry(item)
    id = _string(get(item, :id, get(item, :DOI, "")))
    type = get(CSL_TO_BIBTEX_TYPES, _string(get(item, :type, "misc")), "misc")
    access = BibInternal.Access(
        _string(get(item, :DOI, "")), "", _string(get(item, :URL, "")))
    authors = _names(get(item, :author, nothing))
    editors = _names(get(item, :editor, nothing))
    date = _date(get(item, :issued, nothing))
    title = _string(get(item, :title, ""))
    booktitle = _string(get(item, Symbol("container-title"), ""))
    publisher = _string(get(item, :publisher, ""))
    pages = _string(get(item, :page, ""))
    in_ = BibInternal.In(
        _string(get(item, Symbol("publisher-place"), "")),
        "",
        "",
        publisher,
        _string(get(item, :ISBN, "")),
        _string(get(item, :ISSN, "")),
        booktitle,
        _string(get(item, :issue, "")),
        "",
        pages,
        publisher,
        "",
        "",
        _string(get(item, :volume, ""))
    )
    fields = _fields(item)
    note = _string(get(item, :note, ""))
    eprint = BibInternal.Eprint("", "", "")
    isempty(id) && (id = replace(lowercase(title), r"[^a-z0-9]+" => "-"))
    return BibInternal.Entry(access, authors, booktitle, date, editors,
        eprint, id, in_, fields, note, title, type)
end

function parse_document(input::String)
    diagnostics = BibInternal.Diagnostic[]
    try
        parsed = JSON3.read(input)
        items = parsed isa JSON3.Array ? parsed : [parsed]
        entries = BibInternal.LosslessEntry[]
        for item in items
            entry = parse_entry(item)
            raw = BibInternal.RawEntry(
                kind = "csl", key = entry.id, raw = JSON3.write(item))
            push!(entries, BibInternal.LosslessEntry(entry, raw))
        end
        return BibInternal.BibliographyDocument(
            format = :CSL, entries = entries, source = input)
    catch err
        push!(
            diagnostics,
            BibInternal.Diagnostic(
                code = :parse_error,
                severity = BibInternal.diagnostic_error,
                message = sprint(showerror, err),
                suggestion = "Fix the CSL-JSON document."
            )
        )
    end
    return BibInternal.BibliographyDocument(
        format = :CSL, diagnostics = diagnostics, source = input)
end

end
