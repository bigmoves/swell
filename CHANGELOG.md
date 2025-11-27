# Changelog

## 2.0.0

### Added

- Support for variable default values (`$name: Type = defaultValue`)
- Default values are applied during execution when variables are not provided
- Provided variables override default values
- New `schema.named_type_name` function to get the base type name without List/NonNull wrappers

### Fixed

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
