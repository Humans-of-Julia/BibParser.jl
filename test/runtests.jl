using BibParser, BibParser.BibTeX
using Test

for file in ["test.bib"]
    println("\nstart $file")
    parsed = parse_file("../examples/$file")

    for (k,e) in pairs(parsed)
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
