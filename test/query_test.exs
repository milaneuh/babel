defmodule Babel.QueryTest do
  use ExUnit.Case, async: true
  require Calque

  alias Babel.Query
  alias Babel.Query.UntypedQuery
  alias Babel.ValueIdentifier
  alias Babel.Field
  alias Babel.Query.TypedQuery

  test "add_types builds a TypedQuery from an UntypedQuery with Babel types" do
    untyped = %UntypedQuery{
      file: "queries/babel.sql",
      starting_line: 42,
      name: %ValueIdentifier{name: "my_query"},
      comment: ["-- this is a comment", "-- it spans multiple lines"],
      content: "sql query body"
    }

    # Valid Babel.Type.t() values
    params = [
      1,
      3.14,
      true,
      "foo",
      [1, 2],
      nil
    ]

    returns = [
      %Field{label: "id", type: Babel.Type.int()},
      %Field{label: "name", type: Babel.Type.string()}
    ]

    typed = Babel.Query.add_types(untyped, params, returns)

    """
    GIVEN this untyped query:

      #{inspect(untyped, pretty: true, limit: :infinity)}

    AND the following Babel types for params:

      #{inspect(params)}

    AND the following Babel fields for returns:

      #{inspect(returns)}

    WHEN calling:

      typed = Babel.Query.add_types(untyped, params, returns)

    THEN the resulting TypedQuery should be:

      #{inspect(typed, pretty: true, limit: :infinity)}
    """
    |> Calque.check()
  end

  test "generate_code for a query with no params" do
    query = %TypedQuery{
      file: "queries/no_params.sql",
      starting_line: 1,
      name: %ValueIdentifier{name: "get_all_users"},
      comment: [],
      content: "SELECT * FROM users",
      params: [],
      returns: [
        %Field{label: "id", type: Babel.Type.int()},
        %Field{label: "name", type: Babel.Type.string()}
      ]
    }

    code = Query.generate_code(query)

    fun_head_line =
      code
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "def get_all_users("))

    """
    GIVEN a TypedQuery with no parameters:

      #{inspect(query, pretty: true, limit: :infinity)}

    WHEN generating Elixir code with:

      code = Babel.Query.generate_code(query)

    THEN the generated Elixir code should be:

    #{code}
    """
    |> Calque.check()
  end

  test "generate_code for a query with two params" do
    query = %TypedQuery{
      file: "queries/with_params.sql",
      starting_line: 10,
      name: %ValueIdentifier{name: "find_user"},
      comment: ["-- Find a user by id and status"],
      content: "SELECT * FROM users WHERE id = $1 AND status = $2",
      params: [Babel.Type.int(), Babel.Type.string()],
      returns: [
        %Field{label: "id", type: Babel.Type.int()},
        %Field{label: "name", type: Babel.Type.string()},
        %Field{label: "status", type: Babel.Type.string()}
      ]
    }

    code = Query.generate_code(query)

    fun_head_line =
      code
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "def find_user("))

    """
    GIVEN a TypedQuery with two parameters:

      #{inspect(query, pretty: true, limit: :infinity)}

    WHEN generating Elixir code with:

      code = Babel.Query.generate_code(query)

    THEN the generated Elixir code should be:

    #{code}
    """
    |> Calque.check()
  end
end
