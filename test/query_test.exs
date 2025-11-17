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

  test "generate_code for a query with complex guard types" do
    query = %TypedQuery{
      file: "queries/complex_params.sql",
      starting_line: 5,
      name: %ValueIdentifier{name: "complex_query"},
      comment: ["-- A query using complex guard types"],
      content: "SELECT * FROM events WHERE ids = $1 AND label = $2 AND flags = $3",
      params: [
        Babel.Type.array(Babel.Type.int()),
        Babel.Type.option(Babel.Type.string()),
        Babel.Type.option(Babel.Type.array(Babel.Type.bool()))
      ],
      returns: [
        %Field{label: "id", type: Babel.Type.int()},
        %Field{label: "label", type: Babel.Type.string()},
        %Field{label: "flag", type: Babel.Type.bool()}
      ]
    }

    code = Query.generate_code(query)

    """
    GIVEN a TypedQuery with complex parameter types (arrays, options, nested option of array):

      #{inspect(query, pretty: true, limit: :infinity)}

    WHEN generating Elixir code with:

      code = Babel.Query.generate_code(query)

    THEN the generated Elixir code should include a guarded function clause
    and a fallback clause raising an ArgumentError, with guards derived from Babel.Type.to_guard/2:

    #{code}
    """
    |> Calque.check()
  end

  test "generate_code for a query with params but no returns and a multi line comment" do
    query = %TypedQuery{
      file: "queries/no_returns.sql",
      starting_line: 99,
      name: %ValueIdentifier{name: "log_event"},
      comment: [
        "-- This query logs an event",
        "-- It does not return any row"
      ],
      content: "INSERT INTO logs(message, meta) VALUES ($1, $2)",
      params: [
        Babel.Type.string(),
        Babel.Type.option(Babel.Type.string())
      ],
      returns: []
    }

    code = Query.generate_code(query)

    """
    GIVEN a TypedQuery with parameters but no return fields and a multi line comment:

      #{inspect(query, pretty: true, limit: :infinity)}

    WHEN generating Elixir code with:

      code = Babel.Query.generate_code(query)

    THEN the generated Elixir code should not define an struct module
    but it should have a function with a guard clause and a fallback ArgumentError clause:

    #{code}
    """
    |> Calque.check()
  end
end
