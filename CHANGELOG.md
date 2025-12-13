# Changelog

## 2.1.2

### Fixed

- Union type resolution now uses a canonical type registry, ensuring resolved types have complete field definitions
- Made `build_type_map` public in introspection module for building type registries
- Added `get_union_type_resolver` to extract the type resolver function from union types
- Added `resolve_union_type_with_registry` for registry-based union resolution

## 2.1.1

### Fixed

- Inline fragments on union types within arrays now resolve correctly (was skipping union type resolution for `List[NonNull[Union]]` items)
- Union types are now always traversed during introspection on first encounter, ensuring their `possibleTypes` are properly collected

## 2.1.0

### Added

- Argument type validation: list arguments now produce helpful errors when passed objects instead of lists
- `isOneOf` field in type introspection for INPUT_OBJECT types (GraphQL spec compliance)
- Introspection types are now returned in alphabetical order by name

## 2.0.0

### Added

- Support for variable default values (`$name: Type = defaultValue`)
- Default values are applied during execution when variables are not provided
- Provided variables override default values
- New `schema.named_type_name` function to get the base type name without List/NonNull wrappers

### Fixed

- Integer and float literal arguments are now correctly converted to `value.Int` and `value.Float` instead of `value.String`
- Fragment spread type condition matching now works correctly when parent type is wrapped in NonNull or List
- Inline fragment type condition matching now works correctly with wrapped types
- `__typename` introspection now returns the concrete type name without modifiers

### Breaking Changes

- `Variable` type now has 3 fields: `Variable(name, type_, default_value)` instead of 2
- Code pattern matching on `Variable` must be updated to include the third field
- Migration: Add `None` or `_` as the third argument when constructing or matching `Variable`

## 1.1.0

### Added

- Support for list types in variable definitions (`[Type]`, `[Type!]`, `[Type]!`, `[Type!]!`)

## 1.0.1

- Initial release
