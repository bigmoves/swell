import database
import gleam/io
import gleam/option
import gleam/string
import graphql_schema
import swell/executor
import swell/schema

pub fn main() -> Nil {
  io.println("🌊 Swell + SQLite Example")
  io.println("=" |> string.repeat(50))
  io.println("")

  // Setup in-memory SQLite database
  io.println("Setting up in-memory SQLite database...")
  let assert Ok(conn) = database.setup_database()
  io.println("✓ Database initialized with sample data")
  io.println("")

  // Build GraphQL schema
  let graphql_schema = graphql_schema.build_schema(conn)
  io.println("✓ GraphQL schema created")
  io.println("")

  // Example 1: Query all users
  io.println("Query 1: Get all users")
  io.println("-" |> string.repeat(50))
  let query1 = "{ users { id name email } }"
  io.println("GraphQL: " <> query1)
  io.println("")

  let ctx1 = schema.context(option.None)
  case executor.execute(query1, graphql_schema, ctx1) {
    Ok(executor.Response(data: data, errors: [])) -> {
      io.println("Result: " <> string.inspect(data))
    }
    Ok(executor.Response(data: data, errors: errors)) -> {
      io.println("Data: " <> string.inspect(data))
      io.println("Errors: " <> string.inspect(errors))
    }
    Error(err) -> {
      io.println("Error: " <> err)
    }
  }
  io.println("")

  // Example 2: Query a specific user by ID
  io.println("Query 2: Get user with ID 1")
  io.println("-" |> string.repeat(50))
  let query2 = "{ user(id: 1) { id name email } }"
  io.println("GraphQL: " <> query2)
  io.println("")

  let ctx2 = schema.context(option.None)
  case executor.execute(query2, graphql_schema, ctx2) {
    Ok(executor.Response(data: data, errors: [])) -> {
      io.println("Result: " <> string.inspect(data))
    }
    Ok(executor.Response(data: data, errors: errors)) -> {
      io.println("Data: " <> string.inspect(data))
      io.println("Errors: " <> string.inspect(errors))
    }
    Error(err) -> {
      io.println("Error: " <> err)
    }
  }
  io.println("")

  // Example 3: Query all posts
  io.println("Query 3: Get all posts")
  io.println("-" |> string.repeat(50))
  let query3 = "{ posts { id title content authorId } }"
  io.println("GraphQL: " <> query3)
  io.println("")

  let ctx3 = schema.context(option.None)
  case executor.execute(query3, graphql_schema, ctx3) {
    Ok(executor.Response(data: data, errors: [])) -> {
      io.println("Result: " <> string.inspect(data))
    }
    Ok(executor.Response(data: data, errors: errors)) -> {
      io.println("Data: " <> string.inspect(data))
      io.println("Errors: " <> string.inspect(errors))
    }
    Error(err) -> {
      io.println("Error: " <> err)
    }
  }
  io.println("")

  // Example 4: Create a new user with a mutation
  io.println("Mutation 1: Create a new user")
  io.println("-" |> string.repeat(50))
  let mutation1 =
    "mutation { createUser(input: { name: \"Stephanie Gilmore\", email: \"steph@surfmail.com\" }) { id name email } }"
  io.println("GraphQL: " <> mutation1)
  io.println("")

  let ctx4 = schema.context(option.None)
  case executor.execute(mutation1, graphql_schema, ctx4) {
    Ok(executor.Response(data: data, errors: [])) -> {
      io.println("Result: " <> string.inspect(data))
    }
    Ok(executor.Response(data: data, errors: errors)) -> {
      io.println("Data: " <> string.inspect(data))
      io.println("Errors: " <> string.inspect(errors))
    }
    Error(err) -> {
      io.println("Error: " <> err)
    }
  }
  io.println("")

  // Example 5: Query the newly created user
  io.println("Query 4: Verify the new user was created")
  io.println("-" |> string.repeat(50))
  let query5 = "{ users { id name email } }"
  io.println("GraphQL: " <> query5)
  io.println("")

  let ctx5 = schema.context(option.None)
  case executor.execute(query5, graphql_schema, ctx5) {
    Ok(executor.Response(data: data, errors: [])) -> {
      io.println("Result: " <> string.inspect(data))
    }
    Ok(executor.Response(data: data, errors: errors)) -> {
      io.println("Data: " <> string.inspect(data))
      io.println("Errors: " <> string.inspect(errors))
    }
    Error(err) -> {
      io.println("Error: " <> err)
    }
  }
  io.println("")

  io.println("=" |> string.repeat(50))
  io.println("✓ All examples completed!")
}
