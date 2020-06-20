using BibParser
using Automa
using Test

@test BibParser.parsebibfile("../examples/test.bib")[2] == :ok

# write("actions.dot", Automa.machine2dot(BibParser.bibtex_machine))
# run(`dot -Tsvg -o actions.svg actions.dot`)