# Elixir Idiomatic Patterns

## Pattern Matching vs Case/Map.get

When working with optional fields in maps, prefer pattern matching with multiple function clauses over `case` statements with `Map.get/2`.

### ❌ Less Idiomatic
```elixir
defp maybe_add_field(attributes, meta) do
  case Map.get(meta, :field_name) do
    nil -> attributes
    value when is_binary(value) -> Map.put(attributes, :field_name, value)
    _ -> attributes
  end
end
```

### ✅ More Idiomatic
```elixir
defp maybe_add_field(attributes, %{field_name: field_name}) when not is_nil(field_name),
  do: Map.put(attributes, :field_name, field_name)
defp maybe_add_field(attributes, _meta), do: attributes
```

## General Pattern for Optional Map Fields

This pattern can be generalized for any optional field handling:

```elixir
# For any optional field with type validation
defp maybe_add_field(base, %{field: value}) when is_valid_type(value),
  do: add_field_logic(base, value)
defp maybe_add_field(base, _), do: base

# For multiple optional fields
defp maybe_add_fields(base, %{field1: v1, field2: v2}) when is_binary(v1) and is_integer(v2),
  do: base |> Map.put(:field1, v1) |> Map.put(:field2, v2)
defp maybe_add_fields(base, %{field1: v1}) when is_binary(v1),
  do: Map.put(base, :field1, v1)
defp maybe_add_fields(base, %{field2: v2}) when is_integer(v2),
  do: Map.put(base, :field2, v2)
defp maybe_add_fields(base, _), do: base
```

## Benefits

1. **Pattern Matching**: Leverages Elixir's strength in pattern matching
2. **Guards**: Type validation happens at the function head
3. **Readability**: Clear intent and flow
4. **Performance**: Faster than case statements with Map.get
5. **Exhaustive**: Compiler helps ensure all cases are handled
6. **Maintainable**: Easy to add new patterns by adding function clauses

## When to Use Each Pattern

- **Multiple function clauses**: When you have clear, distinct patterns to match
- **Case statements**: When you need complex logic within each branch
- **with statements**: When you need to chain multiple operations that might fail