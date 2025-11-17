defmodule Babel.Query.UntypedQuery do
  @enforce_keys [:file, :starting_line, :name, :comment, :content]
  defstruct [:file, :starting_line, :name, :comment, :content]

  @type t :: %__MODULE__{
          file: String.t(),
          starting_line: non_neg_integer(),
          name: Babel.ValueIdentifier.t(),
          comment: [String.t()],
          content: String.t()
        }
end

defmodule Babel.Query.TypedQuery do
  @enforce_keys [:file, :starting_line, :name, :comment, :content, :params, :returns]
  defstruct [:file, :starting_line, :name, :comment, :content, :params, :returns]

  @type t :: %__MODULE__{
          file: String.t(),
          starting_line: non_neg_integer(),
          name: Babel.ValueIdentifier.t(),
          comment: [String.t()],
          content: String.t(),
          params: [Babel.Type.t()],
          returns: [Babel.Field.t(Babel.Type.t())]
        }
end

defmodule Babel.Query do
  alias Babel.ValueIdentifier
  alias Babel.Query.{TypedQuery, UntypedQuery}
  alias Babel.Field

  @spec add_types(UntypedQuery.t(), [Babel.Type.t()], [Babel.Field.t(Babel.Type.t())]) ::
          TypedQuery.t()
  def add_types(%UntypedQuery{} = query, params, returns) do
    %TypedQuery{
      file: query.file,
      starting_line: query.starting_line,
      name: query.name,
      comment: query.comment,
      content: query.content,
      params: params,
      returns: returns
    }
  end

  def generate_code(%TypedQuery{} = query) do
    %TypedQuery{
      file: file,
      name: name,
      content: sql_content,
      comment: raw_comment,
      params: params,
      returns: returns
    } = query

    param_name = fn i -> "arg_#{i + 1}" end

    param_vars =
      params
      |> Enum.with_index()
      |> Enum.map(fn {_type, i} -> param_name.(i) end)

    constructor_name = ValueIdentifier.to_type_name(name) <> "Row"

    row_fields =
      Enum.map(returns, fn %Field{label: label} ->
        String.to_atom(label)
      end)

    row_field_typespecs =
      returns
      |> Enum.map(fn %Field{label: label, type: type} ->
        "    #{label}: #{Babel.Type.to_typespec(type)}"
      end)
      |> Enum.join(",\n")

    param_typespecs =
      params
      |> Enum.with_index()
      |> Enum.map(fn {type, i} ->
        "#{param_name.(i)} :: #{Babel.Type.to_typespec(type)}"
      end)
      |> Enum.join(", ")

    guard_expressions =
      params
      |> Enum.with_index()
      |> Enum.map(fn {type, i} ->
        Babel.Type.to_guard(type, param_name.(i))
      end)
      |> Enum.join(" and ")

    guard_clause =
      case guard_expressions do
        "" -> ""
        _ -> " when " <> guard_expressions
      end

    cleaned_comment =
      raw_comment
      |> Enum.map(&String.replace(&1, "--", ""))
      |> Enum.join("\n  ")

    # Only generate the row struct when there are return fields
    row_module_code =
      case returns do
        [] ->
          ""

        _ ->
          """
          defmodule #{constructor_name} do
            @enforce_keys #{inspect(row_fields)}
            defstruct #{inspect(row_fields)}

            @type t :: %__MODULE__{
          #{row_field_typespecs}
            }
          end
          """
      end

    # Return type: struct when there are returns, :ok when there are none
    result_typespec =
      case returns do
        [] -> ":ok"
        _ -> "#{constructor_name}.t()"
      end

    fallback_clause =
      case param_vars do
        [] ->
          ""

        _ ->
          """
          def #{name.name}(#{Enum.join(param_vars, ", ")}) do
            expected = "#{param_typespecs}"
            received = inspect([#{Enum.join(param_vars, ", ")}])

            raise ArgumentError, \"\"\"
            Invalid arguments for #{name.name}/#{length(param_vars)}.

            Expected:
              #{param_typespecs}

            Received:
              \#{received}
            \"\"\"
          end
          """
      end

    function_code = """
    @doc \"\"\"
    Runs the #{name.name} query defined in #{file}.

    #{cleaned_comment}
    \"\"\"
    @spec #{name.name}(#{param_typespecs}) :: #{result_typespec}
    def #{name.name}(#{Enum.join(param_vars, ", ")})#{guard_clause} do
      query = #{inspect(sql_content)}
      params = [#{Enum.join(param_vars, ", ")}]

      # execution TBD
    end
    #{fallback_clause}
    """

    [row_module_code, "", function_code]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end
end
