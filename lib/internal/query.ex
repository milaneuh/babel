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
  alias Babel.Query.FindUserRow
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
      content: content,
      comment: comment,
      params: params,
      returns: returns
    } = query

    param_var = fn i -> "arg_#{i + 1}" end

    function_params =
      params
      |> Enum.with_index()
      |> Enum.map(fn {_type, i} -> param_var.(i) end)

    constructor_name = ValueIdentifier.to_type_name(name) <> "Row"

    struct_fields =
      Enum.map(returns, fn %Field{label: label} -> String.to_atom(label) end)

    struct_field_types =
      returns
      |> Enum.map(fn %Field{label: label, type: type} ->
        "    #{label}: #{Babel.Type.to_typespec(type)}"
      end)
      |> Enum.join(",\n")

    function_param_types =
      params
      |> Enum.with_index()
      |> Enum.map(fn {param_type, i} ->
        "#{param_var.(i)} :: #{Babel.Type.to_typespec(param_type)}"
      end)
      |> Enum.join(", ")

    doc_comment =
      comment
      |> Enum.map(&String.replace(&1, "--", ""))
      |> Enum.join("\n  ")

    struct_module = """
    defmodule #{constructor_name} do
      @enforce_keys #{inspect(struct_fields)}
      defstruct #{inspect(struct_fields)}

      @type t :: %__MODULE__{
    #{struct_field_types}
      }
    end
    """

    fun = """
    @doc \"\"\"
    Runs the #{name.name} query defined in #{file}.

    #{doc_comment}
    \"\"\"
    @spec #{name.name}(#{function_param_types}) :: #{constructor_name}.t()
    def #{name.name}(#{Enum.join(function_params, ", ")}) do
      query = #{inspect(content)}
      params = [#{Enum.join(function_params, ", ")}]

      # execution TBD
    end
    """

    [struct_module, "", fun] |> Enum.join("\n")
  end
end
