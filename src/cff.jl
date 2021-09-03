module CFF

using Dates
using BibInternal
using BibParser
using JSONSchema: Schema, validate
using YAML

export parse_file


const CFF_VERSIONS = Set(["1.2.0"])
const HELP_URL     = "https://github.com/citation-file-format/citation-file-format/blob/main/schema-guide.md"
const PACKAGE_ROOT = pkgdir(BibParser)

"""
Simple error struct used to abort parsing if the CFF version is not supported or invalid.
"""
struct UnsupportedCFFVersion <: Any
    version::String
end

"""
    parse_file(path::String; id::String = "") ->
        Tuple{
            Union{
                BibInternal.Entry,
                UnsupportedCFFVersion,
                YAML.ParserError,
                Any
              },
            Bool
        }

Parse a CFF file located at `path`. Return a tuple with result and boolean status.
On success, a BibInternal.Entry is returned. On failure, the error object is returned.
"""
function parse_file(path; id = "")
    try
        content = YAML.load_file(path; dicttype=Dict{String, Any})
        cff_version = content["cff-version"]
        if !(cff_version in CFF_VERSIONS)
            throw(UnsupportedCFFVersion(cff_version))
        end
        # TODO cache schemas
        schema = Schema(read(joinpath(PACKAGE_ROOT, "src", "cff", "schema-$(cff_version).json"), String))
        errors = validate(content, schema)
        if !isnothing(errors)
            @warn "Invalid CFF file; see schema guide for details: $(HELP_URL)"
            @debug errors

            return errors, false
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
        ), true
    catch err
        if isa(err, YAML.ParserError)
            print("Parse error invalid YAML: ")
        end
        @warn err

        err, false
    end
end

"""
    add_names(content::Dict{String, Any}) -> Vector{BibInternal.Name}
"""
function add_names(content)
    [parse_name(author) for author in content["authors"]]
end

"""
    add_access(content::Dict{String, Any}) -> BibInternal.Access
"""
function add_access(content)
    doi = get(content, "doi", "")
    if haskey(content, "identifiers")
        for identifier in content["identifiers"]
            if get(identifier, "type", "") == "doi"
                doi = identifier["value"]
                break
            end
        end
    end
    url = get(content, "repository-code", "")
    if isempty(url) && haskey(content, "url")
        url = content["url"]
    end

    BibInternal.Access(doi, "", url)
end

"""
    add_date(content::Dict{String, Any}) -> BibInternal.Date
"""
function add_date(content)
    date = get(content, "date-released", "")
    if isempty(date)
        return BibInternal.Date("", "", "")
    end

    date = Date(date, dateformat"yyyy-mm-dd")

    BibInternal.Date(string(Dates.day(date)), string(Dates.month(date)), string(Dates.year(date)))
end

"""
    add_eprint(content::Dict{String, Any}) -> BibInternal.Eprint
"""
function add_eprint(content)
    # need to determine what conventions are widely used in CFFs for this field
    # this is not implemented by other converters (yet?)
    BibInternal.Eprint("", "", "")
end

"""
    generate_id(names::Vector{BibInternal.Name}, title::String, year::String, doi::String) -> String
"""
function generate_id(names, title, year, doi)
    separator = "-"
    dash_title = replace(title, " " => separator)[1:5]
    names_prefix = join(
        map(
            x -> replace(x, " " => separator),
            map(BibParser.Utils.name_to_string, first(names, 2))
        ),
        separator
    )
    prefix = join([names_prefix, dash_title, year], separator)
    if isempty(doi)
        # For CFF 1.2.0, only author and title are required
        # this avoids collisions at the cost of readability
        date_str = Dates.format(Dates.now(), dateformat"YYYY-mm-ddTH:MM:SS.sss")
        "$(prefix)$(separator)$(date_str)"
    else
        "$(prefix)$(separator)$(doi)"
    end
end

"""
    add_in(content::Dict{String, Any}) -> BibInternal.In
"""
function add_in(content)
    address = ""
    # there is no top-level address, so this might not be suitable
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
    pages = start == finish || isempty(finish) ? start : "{$(start)--$(finish)}"
    publisher = get(content, "publisher", Dict())
    publisher = get(publisher, "name", "")

    BibInternal.In(
        address,
        "",                                # chapter
        "",                                # edition
        "",                                # institution
        get(content, "journal", ""),
        string(get(content, "issue", "")), # number
        "",                                # organization
        pages,
        publisher,
        "",                                # school
        "",                                # series
        string(get(content, "volume", ""))
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

"""
    add_type(content::Dict{String, Any}) -> String
"""
function add_type(content)
    get(CFF_TO_BIBTEX_TYPES, content["type"], "misc")
end

"""
    parse_name(Dict{String, Any} -> BibInternal.Name
"""
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
