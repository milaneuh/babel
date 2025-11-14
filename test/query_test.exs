defmodule Babel.QueryTest do
  use ExUnit.Case, async: true
  require Calque

  alias Babel.Query
  alias Babel.Query.UntypedQuery
  alias Babel.ValueIdentifier
  alias Babel.Field

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
      %Field{label: "id", type: 1},
      %Field{label: "name", type: "foo"}
    ]

    typed = Query.add_types(untyped, params, returns)

    """
    GIVEN this untyped query:

      #{inspect(untyped,pretty: true,limit: :infinity)}

    AND the following Babel types for params:

      #{inspect(params)}

    AND the following Babel fields for returns:

      #{inspect(returns)}

    WHEN calling:

      typed = Babel.Query.add_types(untyped, params, returns)

    THEN the resulting TypedQuery should be:

      #{inspect(typed,pretty: true,limit: :infinity)}
    """
    |> Calque.check()
  end
end
