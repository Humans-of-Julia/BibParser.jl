module BibParserCFFExt

import BibParser
import BibParser: parse_bibliography, parse_file
import JSONSchema
import YAML

include("../src/cff.jl")

parse_file(path, ::Val{:CFF}; check) = CFF.parse_file(path)
function parse_bibliography(input, ::Val{:CFF}; check = :error)
    CFF.parse_document(BibParser._read_input(input))
end

end
