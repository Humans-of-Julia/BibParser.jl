"""
    is_zero(t::Tuple)

Extends `iszero` as `is_zero` to `Tuple` types. Return `true` iff all elements of `t` are equal to zero.
"""
is_zero(t::Tuple) = all(iszero, t)

"""
    occurs_in(re, char::Char)
Extends `occursin` as `occurs_in` to test if a regular expression `re` is a match with a `Char`.
"""
occurs_in(re, char::Char) = occursin(re, string(char))

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
