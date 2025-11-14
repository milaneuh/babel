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
  alias Babel.Query.{TypedQuery, UntypedQuery}

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
  end
