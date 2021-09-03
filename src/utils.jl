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

module Utils
"""
    name_to_string(name::BibInternal.Name)

Convert a name in an `Entry` to a string.
"""
function name_to_string(name)
    str = "$(name.particle)"
    if str != "" != name.last
        str *= " "
    end
    str *= name.last
    str *= name.junior == "" ? "" : ", $(name.junior)"
    if name.first != ""
        str *= ", $(name.first)"
    end
    if name.middle != ""
        str *= " $(name.middle)"
    end
    return str
end

end # module
