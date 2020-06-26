using BibParser
using Automa
using Test

for file in ["test.bib", "test2.bib"]
    println("\nstart $file")
    parsed = BibParser.parse_file("../examples/$file")

    for e in values(parsed[1])
        println("|--->type: $(e.kind), key: $(e.key)")
        for (n, v) in pairs(e.fields)
            println("|     |----$n -> $v")
        end
        println("|")
    end
    @test parsed[2] == :ok
end

# write("actions.dot", Automa.machine2dot(BibParser.bibtex_machine))
# run(`dot -Tsvg -o actions.svg actions.dot`)

 