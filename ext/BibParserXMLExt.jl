module BibParserXMLExt

import BibParser
import BibParser: parse_bibliography, parse_file
import EzXML

include("../src/xml.jl")

function parse_file(path, ::Val{:EndNote}; check)
    XMLFormats.parse_endnote_document(read(path, String)).entries
end
function parse_file(path, ::Val{:MODS}; check)
    XMLFormats.parse_mods_document(read(path, String)).entries
end
function parse_bibliography(input, ::Val{:EndNote}; check = :error)
    XMLFormats.parse_endnote_document(BibParser._read_input(input))
end
function parse_bibliography(input, ::Val{:MODS}; check = :error)
    XMLFormats.parse_mods_document(BibParser._read_input(input))
end

end
