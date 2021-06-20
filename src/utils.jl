"""
    Base.iszero(t::Tuple)

Extends `iszero` to `Tuple` types. Return `true` iff all elements of `t` are equal to zero.
"""
Base.iszero(t::Tuple) = all(iszero, t)

"""
    Base.occursin(re, char::Char)
Extends `occursin` to test if a regular expression `re` is a match with a `Char`.
"""
Base.occursin(re, char::Char) = occursin(re, string(char))
