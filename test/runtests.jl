using BibParser
using Automa
using Test

@time println(BibParser.parsebibfile("../examples/test.bib"))

# write("actions.dot", Automa.machine2dot(BibParser.bibtex_machine))
# run(`dot -Tsvg -o actions.svg actions.dot`)