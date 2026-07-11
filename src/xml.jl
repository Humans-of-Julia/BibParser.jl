module XMLFormats

import BibInternal
import EzXML

function _children(node)
    return collect(EzXML.eachelement(node))
end

_nodename(node) = lowercase(replace(EzXML.nodename(node), r"^.*:" => ""))

function _first_text(node, names...)
    wanted = Set(lowercase.(String.(names)))
    for child in _children(node)
        if _nodename(child) in wanted
            return strip(EzXML.nodecontent(child))
        end
    end
    return ""
end

function _desc_text(node, names...)
    wanted = Set(lowercase.(String.(names)))
    for child in _children(node)
        if _nodename(child) in wanted
            return strip(EzXML.nodecontent(child))
        end
        value = _desc_text(child, names...)
        isempty(value) || return value
    end
    return ""
end

function _descendants(node, name)
    found = EzXML.Node[]
    target = lowercase(String(name))
    for child in _children(node)
        _nodename(child) == target && push!(found, child)
        append!(found, _descendants(child, target))
    end
    return found
end

function _name_from_parts(family, given, literal = "")
    if !isempty(literal)
        return BibInternal.Name("", literal, "", "", "")
    end
    return BibInternal.Name("", family, "", given, "")
end

function _date_from_year(year)
    m = match(r"\d{4}", year)
    return BibInternal.Date("", "", isnothing(m) ? year : m.match)
end

function _entry(
        id,
        type,
        title,
        authors,
        editors,
        date,
        access,
        in_;
        booktitle = "",
        note = "",
        raw_fields = Dict{String, String}()
)
    eprint = BibInternal.Eprint("", "", "")
    isempty(id) && (id = replace(lowercase(title), r"[^a-z0-9]+" => "-"))
    return BibInternal.Entry(access, authors, booktitle, date, editors, eprint, id, in_, raw_fields, note, title, type)
end

function _endnote_names(record, role)
    names = BibInternal.Name[]
    contributors = _descendants(record, "contributors")
    for contribs in contributors
        for group in _children(contribs)
            _nodename(group) == lowercase(role) || continue
            for style in _descendants(group, "style")
                value = strip(EzXML.nodecontent(style))
                isempty(value) || push!(names, BibInternal.Name(value))
            end
        end
    end
    return names
end

const ENDNOTE_TO_BIBTEX_TYPES = Dict{String, String}(
    "journal article" => "article",
    "book" => "book",
    "book section" => "incollection",
    "conference paper" => "inproceedings",
    "report" => "techreport",
    "thesis" => "phdthesis",
    "web page" => "misc",
)

function _endnote_entry(record)
    ref_type = lowercase(_desc_text(record, "ref-type"))
    type = get(ENDNOTE_TO_BIBTEX_TYPES, ref_type, "misc")
    title = _desc_text(record, "title")
    secondary = _desc_text(record, "secondary-title")
    id = _desc_text(record, "rec-number", "electronic-resource-num")
    authors = _endnote_names(record, "authors")
    editors = _endnote_names(record, "secondary-authors")
    year = _desc_text(record, "year")
    access = BibInternal.Access(_desc_text(record, "electronic-resource-num"), "", _desc_text(record, "url"))
    in_ = BibInternal.In(
        _desc_text(record, "place-published"),
        "",
        _desc_text(record, "edition"),
        _desc_text(record, "publisher"),
        _desc_text(record, "isbn"),
        _desc_text(record, "isbn"),
        secondary,
        _desc_text(record, "number"),
        "",
        _desc_text(record, "pages"),
        _desc_text(record, "publisher"),
        "",
        "",
        _desc_text(record, "volume")
    )
    return _entry(id, type, title, authors, editors, _date_from_year(year), access, in_; booktitle = secondary, note = _desc_text(record, "abstract"))
end

function parse_endnote_document(input::String)
    diagnostics = BibInternal.Diagnostic[]
    try
        doc = EzXML.parsexml(input)
        records = _descendants(EzXML.root(doc), "record")
        entries = BibInternal.LosslessEntry[]
        for record in records
            entry = _endnote_entry(record)
            raw = BibInternal.RawEntry(kind = "endnote", key = entry.id, raw = string(record))
            push!(entries, BibInternal.LosslessEntry(entry, raw))
        end
        return BibInternal.BibliographyDocument(format = :EndNote, entries = entries, source = input)
    catch err
        push!(diagnostics, BibInternal.Diagnostic(code = :parse_error, severity = BibInternal.diagnostic_error, message = sprint(showerror, err), suggestion = "Fix the EndNote XML document."))
    end
    return BibInternal.BibliographyDocument(format = :EndNote, diagnostics = diagnostics, source = input)
end

function _mods_names(record)
    names = BibInternal.Name[]
    for name in _descendants(record, "name")
        family = ""
        given = ""
        literal = ""
        for part in _children(name)
            _nodename(part) == "namepart" || continue
            type = lowercase(haskey(part, "type") ? part["type"] : "")
            value = strip(EzXML.nodecontent(part))
            if type == "family"
                family = value
            elseif type == "given"
                given = value
            else
                literal = value
            end
        end
        (!isempty(family) || !isempty(given) || !isempty(literal)) &&
            push!(names, _name_from_parts(family, given, literal))
    end
    return names
end

function _mods_entry(record)
    title = _desc_text(record, "title")
    genre = lowercase(_desc_text(record, "genre", "typeOfResource"))
    type = occursin("article", genre) ? "article" :
           occursin("book", genre) ? "book" :
           occursin("conference", genre) ? "inproceedings" : "misc"
    id = _desc_text(record, "identifier")
    date = _date_from_year(_desc_text(record, "dateIssued"))
    journal = _desc_text(record, "title")
    host = ""
    for related in _descendants(record, "relatedItem")
        host = _desc_text(related, "title")
        isempty(host) || break
    end
    !isempty(host) && (journal = host)
    access = BibInternal.Access(_desc_text(record, "identifier"), "", _desc_text(record, "url"))
    in_ = BibInternal.In("", "", "", _desc_text(record, "publisher"), "", "", journal, "", "", "", _desc_text(record, "publisher"), "", "", "")
    return _entry(id, type, title, _mods_names(record), BibInternal.Name[], date, access, in_; booktitle = host)
end

function parse_mods_document(input::String)
    diagnostics = BibInternal.Diagnostic[]
    try
        doc = EzXML.parsexml(input)
        root = EzXML.root(doc)
        records = _nodename(root) == "mods" ? [root] : _descendants(root, "mods")
        entries = BibInternal.LosslessEntry[]
        for record in records
            entry = _mods_entry(record)
            raw = BibInternal.RawEntry(kind = "mods", key = entry.id, raw = string(record))
            push!(entries, BibInternal.LosslessEntry(entry, raw))
        end
        return BibInternal.BibliographyDocument(format = :MODS, entries = entries, source = input)
    catch err
        push!(diagnostics, BibInternal.Diagnostic(code = :parse_error, severity = BibInternal.diagnostic_error, message = sprint(showerror, err), suggestion = "Fix the MODS XML document."))
    end
    return BibInternal.BibliographyDocument(format = :MODS, diagnostics = diagnostics, source = input)
end

end
