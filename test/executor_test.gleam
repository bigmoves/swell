/// Tests for GraphQL Executor
///
/// Tests query execution combining parser + schema + resolvers
import birdie
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import swell/executor
import swell/schema
import swell/value

// Helper to create a simple test schema
fn test_schema() -> schema.Schema {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field("hello", schema.string_type(), "Hello field", fn(_ctx) {
        Ok(value.String("world"))
      }),
      schema.field("number", schema.int_type(), "Number field", fn(_ctx) {
        Ok(value.Int(42))
      }),
      schema.field_with_args(
        "greet",
        schema.string_type(),
        "Greet someone",
        [schema.argument("name", schema.string_type(), "Name to greet", None)],
        fn(_ctx) { Ok(value.String("Hello, Alice!")) },
      ),
    ])

  schema.schema(query_type, None)
}

// Nested object schema for testing
fn nested_schema() -> schema.Schema {
  let user_type =
    schema.object_type("User", "A user", [
      schema.field("id", schema.id_type(), "User ID", fn(_ctx) {
        Ok(value.String("123"))
      }),
      schema.field("name", schema.string_type(), "User name", fn(_ctx) {
        Ok(value.String("Alice"))
      }),
    ])

  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field("user", user_type, "Get user", fn(_ctx) {
        Ok(
          value.Object([
            #("id", value.String("123")),
            #("name", value.String("Alice")),
          ]),
        )
      }),
    ])

  schema.schema(query_type, None)
}

pub fn execute_simple_query_test() {
  let schema = test_schema()
  let query = "{ hello }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(title: "Execute simple query", content: format_response(response))
}

pub fn execute_multiple_fields_test() {
  let schema = test_schema()
  let query = "{ hello number }"

  let result = executor.execute(query, schema, schema.context(None))

  should.be_ok(result)
}

pub fn execute_nested_query_test() {
  let schema = nested_schema()
  let query = "{ user { id name } }"

  let result = executor.execute(query, schema, schema.context(None))

  should.be_ok(result)
}

// Helper to format response for snapshots
fn format_response(response: executor.Response) -> String {
  string.inspect(response)
}

pub fn execute_field_with_arguments_test() {
  let schema = test_schema()
  let query = "{ greet(name: \"Alice\") }"

  let result = executor.execute(query, schema, schema.context(None))

  should.be_ok(result)
}

pub fn execute_invalid_query_returns_error_test() {
  let schema = test_schema()
  let query = "{ invalid }"

  let result = executor.execute(query, schema, schema.context(None))

  // Should return error since field doesn't exist
  case result {
    Ok(executor.Response(_, [_, ..])) -> should.be_true(True)
    Error(_) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn execute_parse_error_returns_error_test() {
  let schema = test_schema()
  let query = "{ invalid syntax"

  let result = executor.execute(query, schema, schema.context(None))

  should.be_error(result)
}

pub fn execute_typename_introspection_test() {
  let schema = test_schema()
  let query = "{ __typename }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute __typename introspection",
    content: format_response(response),
  )
}

pub fn execute_typename_with_regular_fields_test() {
  let schema = test_schema()
  let query = "{ __typename hello }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute __typename with regular fields",
    content: format_response(response),
  )
}

pub fn execute_schema_introspection_query_type_test() {
  let schema = test_schema()
  let query = "{ __schema { queryType { name } } }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute __schema introspection",
    content: format_response(response),
  )
}

// Fragment execution tests
pub fn execute_simple_fragment_spread_test() {
  let schema = nested_schema()
  let query =
    "
    fragment UserFields on User {
      id
      name
    }

    { user { ...UserFields } }
    "

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute simple fragment spread",
    content: format_response(response),
  )
}

// Test for fragment spread on NonNull wrapped type
pub fn execute_fragment_spread_on_non_null_type_test() {
  // Create a schema where the user field returns a NonNull type
  let user_type =
    schema.object_type("User", "A user", [
      schema.field("id", schema.id_type(), "User ID", fn(_ctx) {
        Ok(value.String("123"))
      }),
      schema.field("name", schema.string_type(), "User name", fn(_ctx) {
        Ok(value.String("Alice"))
      }),
    ])

  let query_type =
    schema.object_type("Query", "Root query type", [
      // Wrap user_type in NonNull to test fragment type condition matching
      schema.field("user", schema.non_null(user_type), "Get user", fn(_ctx) {
        Ok(
          value.Object([
            #("id", value.String("123")),
            #("name", value.String("Alice")),
          ]),
        )
      }),
    ])

  let test_schema = schema.schema(query_type, None)

  // Fragment is defined on "User" (not "User!") - this should still work
  let query =
    "
    fragment UserFields on User {
      id
      name
    }

    { user { ...UserFields } }
    "

  let result = executor.execute(query, test_schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute fragment spread on NonNull type",
    content: format_response(response),
  )
}

// Test for list fields with nested selections
pub fn execute_list_with_nested_selections_test() {
  // Create a schema with a list field
  let user_type =
    schema.object_type("User", "A user", [
      schema.field("id", schema.id_type(), "User ID", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
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
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "name") {
              Ok(name_val) -> Ok(name_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("email", schema.string_type(), "User email", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "email") {
              Ok(email_val) -> Ok(email_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  let list_type = schema.list_type(user_type)

  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field("users", list_type, "Get all users", fn(_ctx) {
        // Return a list of user objects
        Ok(
          value.List([
            value.Object([
              #("id", value.String("1")),
              #("name", value.String("Alice")),
              #("email", value.String("alice@example.com")),
            ]),
            value.Object([
              #("id", value.String("2")),
              #("name", value.String("Bob")),
              #("email", value.String("bob@example.com")),
            ]),
          ]),
        )
      }),
    ])

  let schema = schema.schema(query_type, None)

  // Query with nested field selection - only request id and name, not email
  let query = "{ users { id name } }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute list with nested selections",
    content: format_response(response),
  )
}

// Test that arguments are actually passed to resolvers
pub fn execute_field_receives_string_argument_test() {
  let query_type =
    schema.object_type("Query", "Root", [
      schema.field_with_args(
        "echo",
        schema.string_type(),
        "Echo the input",
        [schema.argument("message", schema.string_type(), "Message", None)],
        fn(ctx) {
          // Extract the argument from context
          case schema.get_argument(ctx, "message") {
            Some(value.String(msg)) -> Ok(value.String("Echo: " <> msg))
            _ -> Ok(value.String("No message"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "{ echo(message: \"hello\") }"

  let result = executor.execute(query, test_schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute field with string argument",
    content: format_response(response),
  )
}

// Test list argument
pub fn execute_field_receives_list_argument_test() {
  let query_type =
    schema.object_type("Query", "Root", [
      schema.field_with_args(
        "sum",
        schema.int_type(),
        "Sum numbers",
        [
          schema.argument(
            "numbers",
            schema.list_type(schema.int_type()),
            "Numbers",
            None,
          ),
        ],
        fn(ctx) {
          case schema.get_argument(ctx, "numbers") {
            Some(value.List(_items)) -> Ok(value.String("got list"))
            _ -> Ok(value.String("no list"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "{ sum(numbers: [1, 2, 3]) }"

  let result = executor.execute(query, test_schema, schema.context(None))

  should.be_ok(result)
  |> fn(response) {
    case response {
      executor.Response(
        data: value.Object([#("sum", value.String("got list"))]),
        errors: [],
      ) -> True
      _ -> False
    }
  }
  |> should.be_true
}

// Test object argument (like sortBy)
pub fn execute_field_receives_object_argument_test() {
  let query_type =
    schema.object_type("Query", "Root", [
      schema.field_with_args(
        "posts",
        schema.list_type(schema.string_type()),
        "Get posts",
        [
          schema.argument(
            "sortBy",
            schema.list_type(
              schema.input_object_type("SortInput", "Sort", [
                schema.input_field("field", schema.string_type(), "Field", None),
                schema.input_field(
                  "direction",
                  schema.enum_type("Direction", "Direction", [
                    schema.enum_value("ASC", "Ascending"),
                    schema.enum_value("DESC", "Descending"),
                  ]),
                  "Direction",
                  None,
                ),
              ]),
            ),
            "Sort order",
            None,
          ),
        ],
        fn(ctx) {
          case schema.get_argument(ctx, "sortBy") {
            Some(value.List([value.Object(fields), ..])) -> {
              case dict.from_list(fields) {
                fields_dict -> {
                  case
                    dict.get(fields_dict, "field"),
                    dict.get(fields_dict, "direction")
                  {
                    Ok(value.String(field)), Ok(value.String(dir)) ->
                      Ok(value.String("Sorting by " <> field <> " " <> dir))
                    _, _ -> Ok(value.String("Invalid sort"))
                  }
                }
              }
            }
            _ -> Ok(value.String("No sort"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "{ posts(sortBy: [{field: \"date\", direction: DESC}]) }"

  let result = executor.execute(query, test_schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute field with object argument",
    content: format_response(response),
  )
}

// Variable resolution tests
pub fn execute_query_with_variable_string_test() {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field_with_args(
        "greet",
        schema.string_type(),
        "Greet someone",
        [
          schema.argument("name", schema.string_type(), "Name to greet", None),
        ],
        fn(ctx) {
          case schema.get_argument(ctx, "name") {
            Some(value.String(name)) ->
              Ok(value.String("Hello, " <> name <> "!"))
            _ -> Ok(value.String("Hello, stranger!"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "query Test($name: String!) { greet(name: $name) }"

  // Create context with variables
  let variables = dict.from_list([#("name", value.String("Alice"))])
  let ctx = schema.context_with_variables(None, variables)

  let result = executor.execute(query, test_schema, ctx)

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute query with string variable",
    content: format_response(response),
  )
}

pub fn execute_query_with_variable_int_test() {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field_with_args(
        "user",
        schema.string_type(),
        "Get user by ID",
        [
          schema.argument("id", schema.int_type(), "User ID", None),
        ],
        fn(ctx) {
          case schema.get_argument(ctx, "id") {
            Some(value.Int(id)) ->
              Ok(value.String("User #" <> string.inspect(id)))
            _ -> Ok(value.String("Unknown user"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "query GetUser($userId: Int!) { user(id: $userId) }"

  // Create context with variables
  let variables = dict.from_list([#("userId", value.Int(42))])
  let ctx = schema.context_with_variables(None, variables)

  let result = executor.execute(query, test_schema, ctx)

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute query with int variable",
    content: format_response(response),
  )
}

pub fn execute_query_with_multiple_variables_test() {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field_with_args(
        "search",
        schema.string_type(),
        "Search for something",
        [
          schema.argument("query", schema.string_type(), "Search query", None),
          schema.argument("limit", schema.int_type(), "Max results", None),
        ],
        fn(ctx) {
          case
            schema.get_argument(ctx, "query"),
            schema.get_argument(ctx, "limit")
          {
            Some(value.String(q)), Some(value.Int(l)) ->
              Ok(value.String(
                "Searching for '"
                <> q
                <> "' (limit: "
                <> string.inspect(l)
                <> ")",
              ))
            _, _ -> Ok(value.String("Invalid search"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query =
    "query Search($q: String!, $max: Int!) { search(query: $q, limit: $max) }"

  // Create context with variables
  let variables =
    dict.from_list([
      #("q", value.String("graphql")),
      #("max", value.Int(10)),
    ])
  let ctx = schema.context_with_variables(None, variables)

  let result = executor.execute(query, test_schema, ctx)

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute query with multiple variables",
    content: format_response(response),
  )
}

// Union type execution tests
pub fn execute_union_with_inline_fragment_test() {
  // Create object types that will be part of the union
  let post_type =
    schema.object_type("Post", "A blog post", [
      schema.field("title", schema.string_type(), "Post title", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "title") {
              Ok(title_val) -> Ok(title_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("content", schema.string_type(), "Post content", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "content") {
              Ok(content_val) -> Ok(content_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  let comment_type =
    schema.object_type("Comment", "A comment", [
      schema.field("text", schema.string_type(), "Comment text", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "text") {
              Ok(text_val) -> Ok(text_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  // Type resolver that examines the __typename field
  let type_resolver = fn(ctx: schema.Context) -> Result(String, String) {
    case ctx.data {
      option.Some(value.Object(fields)) -> {
        case list.key_find(fields, "__typename") {
          Ok(value.String(type_name)) -> Ok(type_name)
          _ -> Error("No __typename field found")
        }
      }
      _ -> Error("No data")
    }
  }

  // Create union type
  let search_result_union =
    schema.union_type(
      "SearchResult",
      "A search result",
      [post_type, comment_type],
      type_resolver,
    )

  // Create query type with a field returning the union
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field(
        "search",
        search_result_union,
        "Search for content",
        fn(_ctx) {
          // Return a Post
          Ok(
            value.Object([
              #("__typename", value.String("Post")),
              #("title", value.String("GraphQL is awesome")),
              #("content", value.String("Learn all about GraphQL...")),
            ]),
          )
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)

  // Query with inline fragment
  let query =
    "
    {
      search {
        ... on Post {
          title
          content
        }
        ... on Comment {
          text
        }
      }
    }
    "

  let result = executor.execute(query, test_schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute union with inline fragment",
    content: format_response(response),
  )
}

pub fn execute_union_list_with_inline_fragments_test() {
  // Create object types
  let post_type =
    schema.object_type("Post", "A blog post", [
      schema.field("title", schema.string_type(), "Post title", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "title") {
              Ok(title_val) -> Ok(title_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  let comment_type =
    schema.object_type("Comment", "A comment", [
      schema.field("text", schema.string_type(), "Comment text", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "text") {
              Ok(text_val) -> Ok(text_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  // Type resolver
  let type_resolver = fn(ctx: schema.Context) -> Result(String, String) {
    case ctx.data {
      option.Some(value.Object(fields)) -> {
        case list.key_find(fields, "__typename") {
          Ok(value.String(type_name)) -> Ok(type_name)
          _ -> Error("No __typename field found")
        }
      }
      _ -> Error("No data")
    }
  }

  // Create union type
  let search_result_union =
    schema.union_type(
      "SearchResult",
      "A search result",
      [post_type, comment_type],
      type_resolver,
    )

  // Create query type with a list of unions
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field(
        "searchAll",
        schema.list_type(search_result_union),
        "Search for all content",
        fn(_ctx) {
          // Return a list with mixed types
          Ok(
            value.List([
              value.Object([
                #("__typename", value.String("Post")),
                #("title", value.String("First Post")),
              ]),
              value.Object([
                #("__typename", value.String("Comment")),
                #("text", value.String("Great article!")),
              ]),
              value.Object([
                #("__typename", value.String("Post")),
                #("title", value.String("Second Post")),
              ]),
            ]),
          )
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)

  // Query with inline fragments on list items
  let query =
    "
    {
      searchAll {
        ... on Post {
          title
        }
        ... on Comment {
          text
        }
      }
    }
    "

  let result = executor.execute(query, test_schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute union list with inline fragments",
    content: format_response(response),
  )
}

// Test field aliases
pub fn execute_field_with_alias_test() {
  let schema = test_schema()
  let query = "{ greeting: hello }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  // Response should contain "greeting" as the key, not "hello"
  case response.data {
    value.Object(fields) -> {
      case list.key_find(fields, "greeting") {
        Ok(_) -> should.be_true(True)
        Error(_) -> {
          // Check if it incorrectly used "hello" instead
          case list.key_find(fields, "hello") {
            Ok(_) ->
              panic as "Alias not applied - used 'hello' instead of 'greeting'"
            Error(_) ->
              panic as "Neither 'greeting' nor 'hello' found in response"
          }
        }
      }
    }
    _ -> panic as "Expected object response"
  }
}

// Test multiple aliases
pub fn execute_multiple_fields_with_aliases_test() {
  let schema = test_schema()
  let query = "{ greeting: hello num: number }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute multiple fields with aliases",
    content: format_response(response),
  )
}

// Test mixed aliased and non-aliased fields
pub fn execute_mixed_aliased_fields_test() {
  let schema = test_schema()
  let query = "{ greeting: hello number }"

  let result = executor.execute(query, schema, schema.context(None))

  let response = case result {
    Ok(r) -> r
    Error(_) -> panic as "Execution failed"
  }

  birdie.snap(
    title: "Execute mixed aliased and non-aliased fields",
    content: format_response(response),
  )
}

pub fn execute_query_with_variable_default_value_test() {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field_with_args(
        "greet",
        schema.string_type(),
        "Greet someone",
        [schema.argument("name", schema.string_type(), "Name to greet", None)],
        fn(ctx) {
          case schema.get_argument(ctx, "name") {
            option.Some(value.String(name)) ->
              Ok(value.String("Hello, " <> name <> "!"))
            _ -> Ok(value.String("Hello, stranger!"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "query Test($name: String = \"World\") { greet(name: $name) }"

  // No variables provided - should use default
  let ctx = schema.context_with_variables(None, dict.new())

  let result = executor.execute(query, test_schema, ctx)

  // Debug: print the actual result
  let assert Ok(response) = result
  let assert executor.Response(data: value.Object(fields), errors: _) = response
  let assert Ok(greet_value) = list.key_find(fields, "greet")

  // Should use default value "World" since no variable provided
  greet_value
  |> should.equal(value.String("Hello, World!"))
}

pub fn execute_query_with_variable_overriding_default_test() {
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field_with_args(
        "greet",
        schema.string_type(),
        "Greet someone",
        [schema.argument("name", schema.string_type(), "Name to greet", None)],
        fn(ctx) {
          case schema.get_argument(ctx, "name") {
            option.Some(value.String(name)) ->
              Ok(value.String("Hello, " <> name <> "!"))
            _ -> Ok(value.String("Hello, stranger!"))
          }
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)
  let query = "query Test($name: String = \"World\") { greet(name: $name) }"

  // Provide variable - should override default
  let variables = dict.from_list([#("name", value.String("Alice"))])
  let ctx = schema.context_with_variables(None, variables)

  let result = executor.execute(query, test_schema, ctx)
  result
  |> should.be_ok
  |> fn(response) {
    case response {
      executor.Response(data: value.Object(fields), errors: _) -> {
        case list.key_find(fields, "greet") {
          Ok(value.String("Hello, Alice!")) -> True
          _ -> False
        }
      }
      _ -> False
    }
  }
  |> should.be_true
}

// Test: List argument rejects object value
pub fn list_argument_rejects_object_test() {
  // Create a schema with a field that has a list argument
  let list_arg_field =
    schema.field_with_args(
      "items",
      schema.string_type(),
      "Test field with list arg",
      [
        schema.argument(
          "ids",
          schema.list_type(schema.string_type()),
          "List of IDs",
          None,
        ),
      ],
      fn(_ctx) { Ok(value.String("test")) },
    )

  let query_type = schema.object_type("Query", "Root", [list_arg_field])
  let s = schema.schema(query_type, None)

  // Query with object instead of list should produce an error
  let query = "{ items(ids: {foo: \"bar\"}) }"
  let result = executor.execute(query, s, schema.context(None))

  case result {
    Ok(executor.Response(_, errors)) -> {
      // Should have exactly one error
      list.length(errors)
      |> should.equal(1)

      // Check error message mentions list vs object
      case list.first(errors) {
        Ok(executor.GraphQLError(message, _)) -> {
          string.contains(message, "expects a list")
          |> should.be_true
          string.contains(message, "not an object")
          |> should.be_true
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// Test: List argument accepts list value (sanity check)
pub fn list_argument_accepts_list_test() {
  // Create a schema with a field that has a list argument
  let list_arg_field =
    schema.field_with_args(
      "items",
      schema.string_type(),
      "Test field with list arg",
      [
        schema.argument(
          "ids",
          schema.list_type(schema.string_type()),
          "List of IDs",
          None,
        ),
      ],
      fn(_ctx) { Ok(value.String("success")) },
    )

  let query_type = schema.object_type("Query", "Root", [list_arg_field])
  let s = schema.schema(query_type, None)

  // Query with proper list should work
  let query = "{ items(ids: [\"a\", \"b\"]) }"
  let result = executor.execute(query, s, schema.context(None))

  case result {
    Ok(executor.Response(value.Object(fields), errors)) -> {
      // Should have no errors
      list.length(errors)
      |> should.equal(0)

      // Should return the value
      case list.key_find(fields, "items") {
        Ok(value.String("success")) -> should.be_true(True)
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

// Test: Union resolution uses canonical type registry
// This verifies that when resolving a union type, all fields from the
// canonical type definition are accessible, not just those from the
// union's internal possible_types copy
pub fn execute_union_with_all_fields_via_registry_test() {
  // Create a type with multiple fields to verify complete resolution
  let article_type =
    schema.object_type("Article", "An article", [
      schema.field("id", schema.id_type(), "Article ID", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "id") {
              Ok(id_val) -> Ok(id_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("title", schema.string_type(), "Article title", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "title") {
              Ok(title_val) -> Ok(title_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("body", schema.string_type(), "Article body", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "body") {
              Ok(body_val) -> Ok(body_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("author", schema.string_type(), "Article author", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "author") {
              Ok(author_val) -> Ok(author_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  let video_type =
    schema.object_type("Video", "A video", [
      schema.field("id", schema.id_type(), "Video ID", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "id") {
              Ok(id_val) -> Ok(id_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("title", schema.string_type(), "Video title", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "title") {
              Ok(title_val) -> Ok(title_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
      schema.field("duration", schema.int_type(), "Video duration", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "duration") {
              Ok(duration_val) -> Ok(duration_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  // Type resolver that examines the __typename field
  let type_resolver = fn(ctx: schema.Context) -> Result(String, String) {
    case ctx.data {
      option.Some(value.Object(fields)) -> {
        case list.key_find(fields, "__typename") {
          Ok(value.String(type_name)) -> Ok(type_name)
          _ -> Error("No __typename field found")
        }
      }
      _ -> Error("No data")
    }
  }

  // Create union type
  let content_union =
    schema.union_type(
      "Content",
      "Content union",
      [article_type, video_type],
      type_resolver,
    )

  // Create query type with a field returning the union
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field("content", content_union, "Get content", fn(_ctx) {
        // Return an Article with all fields populated
        Ok(
          value.Object([
            #("__typename", value.String("Article")),
            #("id", value.String("article-1")),
            #("title", value.String("GraphQL Best Practices")),
            #("body", value.String("Here are some tips...")),
            #("author", value.String("Jane Doe")),
          ]),
        )
      }),
    ])

  let test_schema = schema.schema(query_type, None)

  // Query requesting ALL fields from the Article type
  // If the type registry works correctly, all 4 fields should be returned
  let query =
    "
    {
      content {
        ... on Article {
          id
          title
          body
          author
        }
        ... on Video {
          id
          title
          duration
        }
      }
    }
    "

  let result = executor.execute(query, test_schema, schema.context(None))

  case result {
    Ok(executor.Response(value.Object(fields), errors)) -> {
      // Should have no errors
      list.length(errors)
      |> should.equal(0)

      // Check the content field
      case list.key_find(fields, "content") {
        Ok(value.Object(content_fields)) -> {
          // Should have all 4 Article fields
          list.length(content_fields)
          |> should.equal(4)

          // Verify each field is present with correct value
          case list.key_find(content_fields, "id") {
            Ok(value.String("article-1")) -> should.be_true(True)
            _ -> should.fail()
          }
          case list.key_find(content_fields, "title") {
            Ok(value.String("GraphQL Best Practices")) -> should.be_true(True)
            _ -> should.fail()
          }
          case list.key_find(content_fields, "body") {
            Ok(value.String("Here are some tips...")) -> should.be_true(True)
            _ -> should.fail()
          }
          case list.key_find(content_fields, "author") {
            Ok(value.String("Jane Doe")) -> should.be_true(True)
            _ -> should.fail()
          }
        }
        _ -> should.fail()
      }
    }
    Error(err) -> {
      // Print error for debugging
      should.equal(err, "")
    }
    _ -> should.fail()
  }
}

// Test: Union type wrapped in NonNull resolves correctly
// This tests the fix for fields like `node: NonNull(UnionType)` in connections
// Previously, is_union check failed because it only matched bare UnionType
pub fn execute_non_null_union_resolves_correctly_test() {
  // Create object types that will be part of the union
  let like_type =
    schema.object_type("Like", "A like record", [
      schema.field("uri", schema.string_type(), "Like URI", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "uri") {
              Ok(uri_val) -> Ok(uri_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  let follow_type =
    schema.object_type("Follow", "A follow record", [
      schema.field("uri", schema.string_type(), "Follow URI", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "uri") {
              Ok(uri_val) -> Ok(uri_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  // Type resolver that examines the "type" field
  let type_resolver = fn(ctx: schema.Context) -> Result(String, String) {
    case ctx.data {
      option.Some(value.Object(fields)) -> {
        case list.key_find(fields, "type") {
          Ok(value.String(type_name)) -> Ok(type_name)
          _ -> Error("No type field found")
        }
      }
      _ -> Error("No data")
    }
  }

  // Create union type
  let notification_union =
    schema.union_type(
      "NotificationRecord",
      "A notification record",
      [like_type, follow_type],
      type_resolver,
    )

  // Create edge type with node wrapped in NonNull - this is the key scenario
  let edge_type =
    schema.object_type("NotificationEdge", "An edge in the connection", [
      schema.field(
        "node",
        schema.non_null(notification_union),
        // NonNull wrapping union
        "The notification record",
        fn(ctx) {
          case ctx.data {
            option.Some(value.Object(fields)) -> {
              case list.key_find(fields, "node") {
                Ok(node_val) -> Ok(node_val)
                Error(_) -> Ok(value.Null)
              }
            }
            _ -> Ok(value.Null)
          }
        },
      ),
      schema.field("cursor", schema.string_type(), "Cursor", fn(ctx) {
        case ctx.data {
          option.Some(value.Object(fields)) -> {
            case list.key_find(fields, "cursor") {
              Ok(cursor_val) -> Ok(cursor_val)
              Error(_) -> Ok(value.Null)
            }
          }
          _ -> Ok(value.Null)
        }
      }),
    ])

  // Create query type returning a list of edges
  let query_type =
    schema.object_type("Query", "Root query type", [
      schema.field(
        "notifications",
        schema.list_type(edge_type),
        "Get notifications",
        fn(_ctx) {
          Ok(
            value.List([
              value.Object([
                #(
                  "node",
                  value.Object([
                    #("type", value.String("Like")),
                    #("uri", value.String("at://user/like/1")),
                  ]),
                ),
                #("cursor", value.String("cursor1")),
              ]),
              value.Object([
                #(
                  "node",
                  value.Object([
                    #("type", value.String("Follow")),
                    #("uri", value.String("at://user/follow/1")),
                  ]),
                ),
                #("cursor", value.String("cursor2")),
              ]),
            ]),
          )
        },
      ),
    ])

  let test_schema = schema.schema(query_type, None)

  // Query with inline fragments on the NonNull-wrapped union
  let query =
    "
    {
      notifications {
        cursor
        node {
          __typename
          ... on Like {
            uri
          }
          ... on Follow {
            uri
          }
        }
      }
    }
    "

  let result = executor.execute(query, test_schema, schema.context(None))

  case result {
    Ok(response) -> {
      case response.data {
        value.Object(fields) -> {
          case list.key_find(fields, "notifications") {
            Ok(value.List(edges)) -> {
              // Should have 2 edges
              list.length(edges) |> should.equal(2)

              // First edge should be a Like with resolved fields
              case list.first(edges) {
                Ok(value.Object(edge_fields)) -> {
                  case list.key_find(edge_fields, "node") {
                    Ok(value.Object(node_fields)) -> {
                      // __typename should be "Like" (resolved from union)
                      case list.key_find(node_fields, "__typename") {
                        Ok(value.String("Like")) -> should.be_true(True)
                        Ok(value.String(other)) -> should.equal(other, "Like")
                        _ -> should.fail()
                      }
                      // uri should be resolved from inline fragment
                      case list.key_find(node_fields, "uri") {
                        Ok(value.String("at://user/like/1")) ->
                          should.be_true(True)
                        _ -> should.fail()
                      }
                    }
                    _ -> should.fail()
                  }
                }
                _ -> should.fail()
              }
            }
            _ -> should.fail()
          }
        }
        _ -> should.fail()
      }
    }
    Error(err) -> {
      should.equal(err, "")
    }
  }
}
