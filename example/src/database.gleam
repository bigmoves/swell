import gleam/dynamic/decode
import gleam/result
import gleam/string
import sqlight

pub type User {
  User(id: Int, name: String, email: String)
}

pub type Post {
  Post(id: Int, title: String, content: String, author_id: Int)
}

/// Create an in-memory database with users and posts tables
pub fn setup_database() -> Result(sqlight.Connection, sqlight.Error) {
  use conn <- result.try(sqlight.open(":memory:"))

  // Create users table
  let users_sql =
    "
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL
    )
  "

  use _ <- result.try(sqlight.exec(users_sql, conn))

  // Create posts table
  let posts_sql =
    "
    CREATE TABLE posts (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      author_id INTEGER NOT NULL,
      FOREIGN KEY (author_id) REFERENCES users(id)
    )
  "

  use _ <- result.try(sqlight.exec(posts_sql, conn))

  // Insert sample users (surfers)
  let insert_users =
    "
    INSERT INTO users (id, name, email) VALUES
      (1, 'Coco Ho', 'coco@shredmail.com'),
      (2, 'Carissa Moore', 'carissa@barrelmail.com'),
      (3, 'Kelly Slater', 'kslater@bombmail.com')
  "

  use _ <- result.try(sqlight.exec(insert_users, conn))

  // Insert sample posts (surf reports and stories)
  let insert_posts =
    "
    INSERT INTO posts (id, title, content, author_id) VALUES
      (1, 'Sick Barrels at Pipe', 'Bruh, Pipeline was absolutely firing today! Scored some gnarly 8ft tubes, got shacked so hard. Offshore winds all day, totally glassy. So stoked!', 1),
      (2, 'Sunset Bombing', 'Just got done charging some heavy sets at Sunset. Waves were massive, super clean faces. If you are not out here you are missing out big time brah!', 1),
      (3, 'Epic Dawn Patrol Session', 'Woke up at 5am for dawn patrol and it was totally worth it dude. Glassy perfection, no kooks in the lineup. Just me and the ocean vibing. Radical!', 2),
      (4, 'Tow-in at Jaws Was Insane', 'Yo, just finished tow-in session at Jaws. 50 footers rolling through, absolutely gnarly! Got worked on one bomb but that is part of the game. Respect the ocean always bruh.', 3)
  "

  use _ <- result.try(sqlight.exec(insert_posts, conn))

  Ok(conn)
}

/// Get all users from the database
pub fn get_users(conn: sqlight.Connection) -> List(User) {
  let sql = "SELECT id, name, email FROM users"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    decode.success(User(id:, name:, email:))
  }

  sqlight.query(sql, on: conn, with: [], expecting: decoder)
  |> result.unwrap([])
}

/// Get a user by ID
pub fn get_user(
  conn: sqlight.Connection,
  user_id: Int,
) -> Result(User, String) {
  let sql = "SELECT id, name, email FROM users WHERE id = ?"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    decode.success(User(id:, name:, email:))
  }

  case
    sqlight.query(sql, on: conn, with: [sqlight.int(user_id)], expecting: decoder)
  {
    Ok([user]) -> Ok(user)
    Ok([]) -> Error("User not found")
    Ok(_) -> Error("Multiple users found")
    Error(err) -> Error("Database error: " <> string.inspect(err))
  }
}

/// Get all posts from the database
pub fn get_posts(conn: sqlight.Connection) -> List(Post) {
  let sql = "SELECT id, title, content, author_id FROM posts"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    decode.success(Post(id:, title:, content:, author_id:))
  }

  sqlight.query(sql, on: conn, with: [], expecting: decoder)
  |> result.unwrap([])
}

/// Get a post by ID
pub fn get_post(conn: sqlight.Connection, post_id: Int) -> Result(Post, String) {
  let sql = "SELECT id, title, content, author_id FROM posts WHERE id = ?"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    decode.success(Post(id:, title:, content:, author_id:))
  }

  case
    sqlight.query(sql, on: conn, with: [sqlight.int(post_id)], expecting: decoder)
  {
    Ok([post]) -> Ok(post)
    Ok([]) -> Error("Post not found")
    Ok(_) -> Error("Multiple posts found")
    Error(err) -> Error("Database error: " <> string.inspect(err))
  }
}

/// Get posts by author ID
pub fn get_posts_by_author(
  conn: sqlight.Connection,
  author_id: Int,
) -> List(Post) {
  let sql = "SELECT id, title, content, author_id FROM posts WHERE author_id = ?"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    decode.success(Post(id:, title:, content:, author_id:))
  }

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.int(author_id)],
    expecting: decoder,
  )
  |> result.unwrap([])
}

/// Create a new user
pub fn create_user(
  conn: sqlight.Connection,
  name: String,
  email: String,
) -> Result(User, String) {
  let sql = "INSERT INTO users (name, email) VALUES (?, ?) RETURNING id, name, email"

  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    decode.success(User(id:, name:, email:))
  }

  case
    sqlight.query(
      sql,
      on: conn,
      with: [sqlight.text(name), sqlight.text(email)],
      expecting: decoder,
    )
  {
    Ok([user]) -> Ok(user)
    Ok([]) -> Error("Failed to create user")
    Ok(_) -> Error("Unexpected result")
    Error(err) -> Error("Database error: " <> string.inspect(err))
  }
}
