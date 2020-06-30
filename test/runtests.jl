using BibParser
using Automa
using Test

for file in ["test.bib", "test2.bib"]
    println("\nstart $file")
    parsed = BibParser.parse_file("../examples/$file")

    println("type: $(typeof(parsed))")

    for e in values(parsed[1])
        println("|--->type: $(typeof(e)), key: $(e.id)")
        for fn in fieldnames(typeof(e))
            println("|     |----$(string(fn)) -> metaprogramming to hard")
        end
        for (n, v) in pairs(e.other)
            println("|     |----$n -> $v")
        end
        println("|")
    end
    @test parsed[2] == :ok
    println(parsed[1])
end

# write("actions.dot", Automa.machine2dot(BibParser.bibtex_machine))
# run(`dot -Tsvg -o actions.svg actions.dot`)

