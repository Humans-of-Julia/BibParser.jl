using BibParser
using Automa
using Test

# write your own tests here
println(BibParser.parsebib("../examples/tidy.bib"))

write("actions.dot", Automa.machine2dot(BibParser.bibmachine))
run(`dot -Tpng -o actions.png actions.dot`)