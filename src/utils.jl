Base.iszero(t::Tuple) = iszero(t[1]) && iszero(t[2])
Base.occursin(re, char::Char) = occursin(re, string(char))

rev(char) = char == '(' ? ')' : '{'
