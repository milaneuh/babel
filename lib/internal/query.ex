defmodule Babel.Query.UntypedQuery do
  @enforce_keys [:file, :starting_line, :name, :comment, :content, :parent_folder]
  defstruct [:file, :starting_line, :name, :comment, :content, :parent_folder]

  @type t :: %__MODULE__{
          file: String.t(),
          starting_line: non_neg_integer(),
          name: Babel.ValueIdentifier.t(),
          comment: [String.t()],
          content: String.t(),
          parent_folder: String.t()
        }
end

defmodule Babel.Query.TypedQuery do
  @enforce_keys [
    :file,
    :starting_line,
    :name,
    :comment,
    :content,
    :parent_folder,
    :params,
    :returns
  ]
  defstruct [:file, :starting_line, :name, :comment, :content, :parent_folder, :params, :returns]

  @type t :: %__MODULE__{
          file: String.t(),
          starting_line: non_neg_integer(),
          name: Babel.ValueIdentifier.t(),
          comment: [String.t()],
          content: String.t(),
          parent_folder: String.t(),
          params: [Babel.Type.t()],
          returns: [Babel.Field.t(Babel.Type.t())]
        }
end

defmodule Babel.Query do
  alias Babel.ValueIdentifier
  alias Babel.Query.{TypedQuery, UntypedQuery}
  alias Babel.Field
  alias Babel.FileHandling.SqlFile

  @spec add_types(UntypedQuery.t(), [Babel.Type.t()], [Babel.Field.t(Babel.Type.t())]) ::
          TypedQuery.t()
  def add_types(%UntypedQuery{} = query, params, returns) do
    %TypedQuery{
      file: query.file,
      starting_line: query.starting_line,
      name: query.name,
      comment: query.comment,
      content: query.content,
      parent_folder: query.parent_folder,
      params: params,
      returns: returns
    }
  end

  @spec from_sql_file(SqlFile.t()) ::
          {:ok, UntypedQuery.t()} | {:error, :empty_sql_file}
  def from_sql_file(%SqlFile{} = file) do
    %{name: name, path: path, content: content} = file

    parent_folder = extract_parent_folder(path)
    trimmed = String.trim(content)

    cond do
      trimmed == "" ->
        {:error, :empty_sql_file}

      true ->
        {:ok, name} = ValueIdentifier.new(name)
        comment = extract_comment(content)

        {:ok,
         %UntypedQuery{
           file: path,
           starting_line: 1,
           name: name,
           comment: comment,
           content: content,
           parent_folder: parent_folder
         }}
    end
  end

  @spec generate_code(TypedQuery.t()) :: String.t()
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

  defp extract_comment(query) when is_binary(query) do
    do_extract_comment(query, [])
  end

  defp do_extract_comment(query, lines) do
    case String.trim_leading(query) do
      <<"--", rest::binary>> ->
        case String.split(rest, "\n", parts: 2) do
          [line, rest_after_line] ->
            do_extract_comment(rest_after_line, [String.trim(line) | lines])

          [last_line] ->
            do_extract_comment("", [String.trim(last_line) | lines])
        end

      _other ->
        Enum.reverse(lines)
    end
  end

  defp extract_parent_folder(path) do
    path
    |> Path.dirname()
    |> Path.split()
    |> Enum.at(-2)
  end
end
