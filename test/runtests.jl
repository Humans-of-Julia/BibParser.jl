using BibParser, BibParser.BibTeXParser
using Test

for file in ["test.bib"]
    println("\nstart $file")
    parsed = parse_file("../examples/$file")

    println("type: $(typeof(parsed))")

    for (k,e) in pairs(parsed)
        println("|--->type: $(typeof(e)), key: $(e.id)")
        for fn in fieldnames(typeof(e))
            println("|     |----$(string(fn)) -> metaprogramming too hard") # TODO: better printing
        end
        for (n, v) in pairs(e.fields)
            println("|     |----$n -> $v")
        end
        println("|")
    end
    # @test parsed[2] == :ok
end

