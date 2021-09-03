module CFF

using Dates
using BibInternal
using JSONSchema: Schema, validate
using YAML

import ..Utils

export parse_file

struct UnsupportedCFFVersion <: Any
end

const CFF_VERSIONS = Set(["1.2.0"])

function parse_file(path; id = "")
    try
        content = YAML.load_file(path; dicttype=Dict{String, Any})
        cff_version = content["cff-version"]
        if !(cff_version in CFF_VERSIONS)
            throw(UnsupportedCFFVersion())
        end
        # TODO cache schemas
        schema = Schema(read(joinpath("src", "cff", "schema-" * cff_version * ".json"), String))
        errors = validate(content, schema)
        if errors === nothing
            content
        else
            println(errors)

            false
        end

        if haskey(content, "preferred-citation")
            content = content["preferred-citation"]
        end
        names     = add_names(content)
        access    = add_access(content)
        # no booktitle in CFF
        booktitle = ""
        date      = add_date(content)
        # editors appear only in references in CFF
        editors   = []
        eprint    = add_eprint(content)
        title     = content["title"] # always exists
        id        = generate_id(names, title, date.year, access.doi)
        in_       = add_in(content)
        fields    = Dict()
        type_     = add_type(content)

        BibInternal.Entry(
            access, names, booktitle, date, editors, eprint, id, in_, fields, title, type_
        )
    catch err
        if isa(err, YAML.ParserError)
            print("Parse error invalid YAML: ")
        end
        println(err)

        false
    end
end

function add_names(content)
    [parse_name(author) for author in content["authors"]]
end

function add_access(content)
    doi = get(content, "doi", "")
    if haskey(content, "identifiers") && !isempty(content["identifiers"])
        doi = content["identifiers"][1]["doi"]
    end
    url = get(content, "repository-code", "")
    if isempty(url) && haskey(content, "url")
        url = content["url"]
    end

    BibInternal.Access(doi, "", url)
end

function add_date(content)
    date = get(content, "date-released", "")
    if isempty(date)
        return BibInternal.Date("", "", "")
    end

    date = Date(date, dateformat"yyyy-mm-dd")

    BibInternal.Date(Dates.day(date), Dates.month(date), Dates.year(date))
end

function add_eprint(content)
    # need to determine what conventions are widely used in CFFs for this
    # this is not implemented by other converters (yet?)
    BibInternal.Eprint("", "", "")
end

function generate_id(names, title, year, doi)
    separator = "-"
    dash_title = replace(title, " " => separator)[1:5]
    names_prefix = join(
        map(
            x -> replace(x, " " => separator),
            map(Utils.name_to_string, first(names, 2))
        ),
        separator
    )
    prefix = join([names_prefix, dash_title, year], separator)
    if isempty(doi)
        # For CFF 1.2.0, only author and title are required
        # this avoids collisions at the cost of readability
        date_str = Dates.format(Dates.now(), dateformat"YYYY-mm-ddTH:MM:SS.sss")
        prefix * date_str
    else
        prefix * doi
    end
end

function add_in(content)
    address = ""
    if !isempty(content["authors"])
        for author in content["authors"]
            if haskey(author, "address")
                address = author["address"]
                break
            end
        end
    end
    start  = get(content, "start", "")
    finish = get(content, "end", "")
    pages = start == finish || isempty(finish) ? start : "{" * start * "--" * finish * "}"
    publisher = get(content, "publisher", Dict())
    publisher = get(publisher, "name", "")

    BibInternal.In(
        address,
        "",                         # chapter
        "",                         # edition
        "",                         # institution
        get(content, "journal", ""),
        get(content, "issue", ""),  # number
        "",                         # organization
        pages,
        publisher,
        "",                         # school
        "",                         # series
        get(content, "volume", "")
    )
end

const CFF_TO_BIBTEX_TYPES = Dict{String, String}(
    [
        "article"           => "article",
        "book"              => "book",
        "manual"            => "manual",
        "unpublished"       => "unpublished",
        "conference"        => "proceedings",
        "proceedings"       => "proceedings",
        "conference-paper"  => "proceedings",
        "magazine-article"  => "article",
        "newspaper-article" => "article",
        "pamphlet"          => "booklet"
    ]
)

function add_type(content)
    get(CFF_TO_BIBTEX_TYPES, content["type"], "misc")
end

function parse_name(author)
    if haskey(author, "name")  # note: cffconvert does not treat this case
        BibInternal.Name("", author["name"], "", "", "")
    else
        BibInternal.Name(
            get(author, "name-particle", ""),
            get(author, "family-names", ""),
            get(author, "name-suffix", ""),
            get(author, "given-names", ""),
            ""  # there is no middle name in CFF
        )
    end
end

end # module
