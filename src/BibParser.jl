module BibParser

# Import Automa.jl package to create the Finite-State Machine of the BibTeX grammar
import Automa
import Automa.RegExp: @re_str

import BibInternal, BibInternal.Entry, BibInternal.EntryFields

# Define the notation for RegExp in Automa.jl
const re = Automa.RegExp

include("bibtex.jl")

include("precompile.jl")
_precompile_()

end # module
