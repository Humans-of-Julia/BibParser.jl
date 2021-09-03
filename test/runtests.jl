using BibParser, BibParser.BibTeX
using Test

const PACKAGE_ROOT = pkgdir(BibParser)

function test_bibtex()
    for file in ["test.bib", "error.bib"]
        println("\nstart $file")
        parsed = parse_file(joinpath(PACKAGE_ROOT, "examples", "$file"))

        for (k, e) in pairs(parsed)
            println("|--->$(e.id)")
            for fn in fieldnames(typeof(e))
                println("|     |----$(string(fn)) -> parsed!") # TODO: better printing
            end
            for (n, v) in pairs(e.fields)
                println("|     |----$n -> $v")
            end
            println("|")
        end
    end
end

function test_cff()
    for file in ["CITATION.cff", "invalid_yaml.cff", "invalid_version.cff", "invalid_schema.cff"]
        @info "Start $file"
        parsed, result = parse_file(joinpath(PACKAGE_ROOT, "examples", file), :CFF)
        if result
            @info "OK"
        else
            @info "Error"
        end
    end
end


test_bibtex()
test_cff()
