defmodule Babel.FileHandlingTest do
  use ExUnit.Case, async: false
  require Calque

  setup do
    test_dir = Path.join(System.tmp_dir!(), "babel_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(test_dir)

    original_config = Application.get_env(:babel, :sql_path_pattern)

    on_exit(fn ->
      File.rm_rf!(test_dir)

      if original_config do
        Application.put_env(:babel, :sql_path_pattern, original_config)
      else
        Application.delete_env(:babel, :sql_path_pattern)
      end
    end)

    {:ok, test_dir: test_dir, original_config: original_config}
  end

  describe "with default lib/**/*.sql pattern" do
    test "collects all SQL files matching default pattern", %{test_dir: test_dir} do
      Application.delete_env(:babel, :sql_path_pattern)

      create_files(test_dir, [
        {"lib/sql/users.sql", "SELECT * FROM users;"},
        {"lib/sql/posts.sql", "SELECT id, title FROM posts;"},
        {"lib/deep/nested/sql/comments.sql", "SELECT * FROM comments;"},
        {"lib/ignored.txt", "not sql"},
        {"priv/sql/migrations.sql", "CREATE TABLE foo;"},
        {"src/queries.sql", "SELECT 1;"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN this file structure:
        lib/
          sql/
            users.sql: "SELECT * FROM users;"
            posts.sql: "SELECT id, title FROM posts;"
          deep/
            nested/
              sql/
                comments.sql: "SELECT * FROM comments;"
          ignored.txt: "not sql"
        priv/
          sql/
            migrations.sql: "CREATE TABLE foo;"
        src/
          queries.sql: "SELECT 1;"

      WHEN collecting with default pattern "lib/**/*.sql"

      THEN we collect only files under lib/ with .sql extension:
      #{format_results(result)}
      """
      |> Calque.check()
    end

    test "handles empty SQL files", %{test_dir: test_dir} do
      Application.delete_env(:babel, :sql_path_pattern)

      create_files(test_dir, [
        {"lib/sql/empty.sql", ""},
        {"lib/sql/whitespace.sql", "   \n\n   "},
        {"lib/sql/normal.sql", "SELECT 1;"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN SQL files with various content states:
        lib/sql/empty.sql: ""
        lib/sql/whitespace.sql: "   \\n\\n   "
        lib/sql/normal.sql: "SELECT 1;"

      WHEN collecting

      THEN we collect all files including empty ones:
      #{format_results(result)}
      """
      |> Calque.check()
    end

    test "returns empty list when no SQL files exist", %{test_dir: test_dir} do
      Application.delete_env(:babel, :sql_path_pattern)

      create_files(test_dir, [
        {"lib/queries.txt", "not sql"},
        {"lib/data.json", "{}"},
        {"README.md", "# Hello"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN no .sql files in lib directory:
        lib/queries.txt
        lib/data.json
        README.md

      WHEN collecting

      THEN we get an empty list:
      #{inspect(result, pretty: true)}
      """
      |> Calque.check()
    end
  end

  describe "with custom patterns" do
    test "collects with custom pattern", %{test_dir: test_dir} do
      Application.put_env(:babel, :sql_path_pattern, "priv/**/*.sql")

      create_files(test_dir, [
        {"lib/ignored.sql", "SELECT 1;"},
        {"priv/queries/users.sql", "SELECT * FROM users;"},
        {"priv/migrations/001_init.sql", "CREATE TABLE users;"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN custom pattern "priv/**/*.sql" and files:
        lib/ignored.sql
        priv/queries/users.sql
        priv/migrations/001_init.sql

      WHEN collecting

      THEN we only get files from priv/:
      #{format_results(result)}
      """
      |> Calque.check()
    end

    test "handles root-level pattern", %{test_dir: test_dir} do
      Application.put_env(:babel, :sql_path_pattern, "*.sql")

      create_files(test_dir, [
        {"query.sql", "SELECT 1;"},
        {"lib/nested.sql", "SELECT 2;"},
        {"root.sql", "SELECT 3;"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN pattern "*.sql" (root only) and files:
        query.sql
        root.sql
        lib/nested.sql

      WHEN collecting

      THEN we only get root-level SQL files:
      #{format_results(result)}
      """
      |> Calque.check()
    end
  end

  describe "path handling" do
    test "returns relative paths from project root", %{test_dir: test_dir} do
      Application.delete_env(:babel, :sql_path_pattern)

      create_files(test_dir, [
        {"lib/sql/query.sql", "SELECT 1;"}
      ])

      [file] = Babel.FileHandling.collect_sql_files(test_dir)

      """
      GIVEN an SQL file at lib/sql/query.sql

      WHEN "lib/sql/query.sql" is collected with absolute path of the test repo

      THEN the SqlFile struct contains:
        path: #{inspect(file.path)}
        name: #{inspect(file.name)}
        content: #{inspect(file.content)}

      AND path is relative to project root
      """
      |> Calque.check()
    end

    test "handles special characters in filenames", %{test_dir: test_dir} do
      Application.delete_env(:babel, :sql_path_pattern)

      create_files(test_dir, [
        {"lib/user-queries.sql", "SELECT 1;"},
        {"lib/get_user_by_id.sql", "SELECT 2;"},
        {"lib/query.v2.sql", "SELECT 3;"}
      ])

      result = Babel.FileHandling.collect_sql_files(test_dir)
      names = result |> Enum.map(& &1.name) |> Enum.sort()

      """
      GIVEN SQL files with various naming styles:
        lib/user-queries.sql
        lib/get_user_by_id.sql
        lib/query.v2.sql

      WHEN collecting

      THEN names are extracted without .sql extension:
      #{inspect(names)}
      """
      |> Calque.check()
    end
  end

  defp create_files(base_dir, files) do
    for {path, content} <- files do
      full_path = Path.join(base_dir, path)
      full_path |> Path.dirname() |> File.mkdir_p!()
      File.write!(full_path, content)
    end
  end

  defp format_results(results) do
    results
    |> Enum.sort_by(& &1.path)
    |> Enum.map(fn %{path: path, name: name, content: content} ->
      "  #{path} (name: #{name}): #{inspect(String.trim(content))}"
    end)
    |> Enum.join("\n")
  end
end
