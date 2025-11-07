# Swell

A GraphQL implementation in Gleam providing query parsing, execution, and introspection support.

![Swell](https://images.unsplash.com/photo-1616645728806-838c6bf184af?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=2340)

## Features

- Query parsing and execution
- Mutations with input types
- Subscriptions for real-time updates
- Introspection support
- Type-safe schema builder
- Fragment support (inline and named)

## Quick Start

Check out the `/example` directory for an example with SQLite.

## Usage

```gleam
import swell/schema
import swell/executor
import swell/value

// Define your schema
let user_type = schema.object_type("User", "A user", [
  schema.field("id", schema.id_type(), "User ID", fn(ctx) {
    case ctx.data {
      Some(value.Object(fields)) -> {
        case list.key_find(fields, "id") {
          Ok(id_val) -> Ok(id_val)
          Error(_) -> Ok(value.Null)
        }
      }
      _ -> Ok(value.Null)
    }
  }),
  schema.field("name", schema.string_type(), "User name", fn(ctx) {
    case ctx.data {
      Some(value.Object(fields)) -> {
        case list.key_find(fields, "name") {
          Ok(name_val) -> Ok(name_val)
          Error(_) -> Ok(value.Null)
        }
      }
      _ -> Ok(value.Null)
    }
  }),
])

let query_type = schema.object_type("Query", "Root query", [
  schema.field("user", user_type, "Get a user", fn(_ctx) {
    Ok(value.Object([
      #("id", value.String("1")),
      #("name", value.String("Alice")),
    ]))
  }),
])

let my_schema = schema.schema(query_type, None)

// Execute a query
let result = executor.execute("{ user { id name } }", my_schema, schema.context(None))
```

## Known Limitations

- Directives not implemented (`@skip`, `@include`, custom directives)
- Interface types not implemented
- Custom scalar serialization/deserialization (can define custom scalar types but no validation or coercion beyond built-in types)

## Development

```sh
gleam test  # Run tests
gleam build # Build the package
```
