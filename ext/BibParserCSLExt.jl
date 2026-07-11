module BibParserCSLExt

import BibParser
import BibParser: parse_bibliography, parse_file
import JSON3

include("../src/csl.jl")

parse_file(path, ::Val{:CSL}; check) = CSL.parse_document(read(path, String)).entries
function parse_bibliography(input, ::Val{:CSL}; check = :error)
    CSL.parse_document(BibParser._read_input(input))
end

end
