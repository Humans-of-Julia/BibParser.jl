module BibTeX

using CombinedParsers
using CombinedParsers.Regexp

# Concatenation with spaces: \times (tab completion)
× = (x, y) -> x * Repeat(re"[\t\n\r ]") * y

# Basic regexp
publication_type = re"@[a-z]+"i
field_name = re"[a-z]+"i
in_braces = re"[^@{}]"
in_quotes = re"[^\"]"
key = re"[a-z][0-9a-z_:/\-\\]*"i
left_brace = re"\{"
number = re"[0-9]+"
quotes = re"\""
right_brace = re"\}"
space = re"[\t\n\r ]"

# Complex regexp
brace_value = left_brace * Repeat(in_braces | left_brace | right_brace) * right_brace
quote_value = quotes * Repeat(brace_value | in_quotes) * quotes
value = number | quote_value | brace_value
field_value = Repeat(value × re"#") × value
field = field_name × re"=" × field_value
fields = Repeat(re"," × field)
entry_content = key × fields × Optional(re",")
brace_entry = left_brace × entry_content × right_brace
publication = publication_type × brace_entry
bibliography = Repeat(space | publication)

end