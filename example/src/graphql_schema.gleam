import database
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import sqlight
import swell/schema
import swell/value

/// Build the User type (without nested posts to avoid circular dependency)
pub fn user_type() -> schema.Type {
  schema.object_type("User", "A user in the system", [
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
    schema.field("email", schema.string_type(), "User email", fn(ctx) {
      case ctx.data {
        Some(value.Object(fields)) -> {
          case list.key_find(fields, "email") {
            Ok(email_val) -> Ok(email_val)
            Error(_) -> Ok(value.Null)
          }
        }
        _ -> Ok(value.Null)
      }
    }),
  ])
}

/// Build the Post type (without nested author to avoid circular dependency)
pub fn post_type() -> schema.Type {
  schema.object_type("Post", "A blog post", [
    schema.field("id", schema.id_type(), "Post ID", fn(ctx) {
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
    schema.field("title", schema.string_type(), "Post title", fn(ctx) {
      case ctx.data {
        Some(value.Object(fields)) -> {
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
        Some(value.Object(fields)) -> {
          case list.key_find(fields, "content") {
            Ok(content_val) -> Ok(content_val)
            Error(_) -> Ok(value.Null)
          }
        }
        _ -> Ok(value.Null)
      }
    }),
    schema.field("authorId", schema.int_type(), "Author ID", fn(ctx) {
      case ctx.data {
        Some(value.Object(fields)) -> {
          case list.key_find(fields, "author_id") {
            Ok(author_id_val) -> Ok(author_id_val)
            Error(_) -> Ok(value.Null)
          }
        }
        _ -> Ok(value.Null)
      }
    }),
  ])
}

/// Convert a User to a GraphQL Value
fn user_to_value(user: database.User) -> value.Value {
  value.Object([
    #("id", value.Int(user.id)),
    #("name", value.String(user.name)),
    #("email", value.String(user.email)),
  ])
}

/// Convert a Post to a GraphQL Value
fn post_to_value(post: database.Post) -> value.Value {
  value.Object([
    #("id", value.Int(post.id)),
    #("title", value.String(post.title)),
    #("content", value.String(post.content)),
    #("author_id", value.Int(post.author_id)),
  ])
}

/// Build the Query type
pub fn query_type(conn: sqlight.Connection) -> schema.Type {
  schema.object_type("Query", "Root query type", [
    schema.field("users", schema.list_type(user_type()), "Get all users", fn(
      _ctx,
    ) {
      let users = database.get_users(conn)
      Ok(value.List(list.map(users, user_to_value)))
    }),
    schema.field_with_args(
      "user",
      user_type(),
      "Get a user by ID",
      [
        schema.argument(
          "id",
          schema.non_null(schema.id_type()),
          "User ID",
          None,
        ),
      ],
      fn(ctx) {
        case schema.get_argument(ctx, "id") {
          Some(value.Int(user_id)) -> {
            case database.get_user(conn, user_id) {
              Ok(user) -> Ok(user_to_value(user))
              Error(err) -> Error(err)
            }
          }
          Some(value.String(user_id_str)) -> {
            case int.parse(user_id_str) {
              Ok(user_id) -> {
                case database.get_user(conn, user_id) {
                  Ok(user) -> Ok(user_to_value(user))
                  Error(err) -> Error(err)
                }
              }
              Error(_) -> Error("Invalid user ID format")
            }
          }
          _ -> Error("User ID is required")
        }
      },
    ),
    schema.field("posts", schema.list_type(post_type()), "Get all posts", fn(
      _ctx,
    ) {
      let posts = database.get_posts(conn)
      Ok(value.List(list.map(posts, post_to_value)))
    }),
    schema.field_with_args(
      "post",
      post_type(),
      "Get a post by ID",
      [
        schema.argument(
          "id",
          schema.non_null(schema.id_type()),
          "Post ID",
          None,
        ),
      ],
      fn(ctx) {
        case schema.get_argument(ctx, "id") {
          Some(value.Int(post_id)) -> {
            case database.get_post(conn, post_id) {
              Ok(post) -> Ok(post_to_value(post))
              Error(err) -> Error(err)
            }
          }
          Some(value.String(post_id_str)) -> {
            case int.parse(post_id_str) {
              Ok(post_id) -> {
                case database.get_post(conn, post_id) {
                  Ok(post) -> Ok(post_to_value(post))
                  Error(err) -> Error(err)
                }
              }
              Error(_) -> Error("Invalid post ID format")
            }
          }
          _ -> Error("Post ID is required")
        }
      },
    ),
  ])
}

/// Input type for creating a user
pub fn create_user_input() -> schema.Type {
  schema.input_object_type("CreateUserInput", "Input for creating a user", [
    schema.input_field(
      "name",
      schema.non_null(schema.string_type()),
      "User name",
      None,
    ),
    schema.input_field(
      "email",
      schema.non_null(schema.string_type()),
      "User email",
      None,
    ),
  ])
}

/// Build the Mutation type
pub fn mutation_type(conn: sqlight.Connection) -> schema.Type {
  schema.object_type("Mutation", "Root mutation type", [
    schema.field_with_args(
      "createUser",
      user_type(),
      "Create a new user",
      [
        schema.argument(
          "input",
          schema.non_null(create_user_input()),
          "User data",
          None,
        ),
      ],
      fn(ctx) {
        case schema.get_argument(ctx, "input") {
          Some(value.Object(fields)) -> {
            let name_result = list.key_find(fields, "name")
            let email_result = list.key_find(fields, "email")

            case name_result, email_result {
              Ok(value.String(name)), Ok(value.String(email)) -> {
                case database.create_user(conn, name, email) {
                  Ok(user) -> Ok(user_to_value(user))
                  Error(err) -> Error(err)
                }
              }
              _, _ -> Error("Invalid input: name and email are required")
            }
          }
          _ -> Error("Invalid input format")
        }
      },
    ),
  ])
}

/// Build the complete GraphQL schema
pub fn build_schema(conn: sqlight.Connection) -> schema.Schema {
  schema.schema(query_type(conn), Some(mutation_type(conn)))
}
