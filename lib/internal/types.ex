defmodule Babel.Type do
  @type primitive ::
          :int
          | :float
          | :bool
          | :string

  @type t ::
          primitive()
          | {:array, t()}
          | {:option, t()}

  def int, do: :int
  def float, do: :float
  def bool, do: :bool
  def string, do: :string

  def array(inner), do: {:array, inner}
  def option(inner), do: {:option, inner}

  @spec to_typespec(__MODULE__.t()) :: String.t()
  def to_typespec(:int), do: "integer()"
  def to_typespec(:float), do: "float()"
  def to_typespec(:bool), do: "boolean()"
  def to_typespec(:string), do: "String.t()"

  def to_typespec({:array, inner}),
    do: "[#{to_typespec(inner)}]"

  def to_typespec({:option, inner}),
    do: "#{to_typespec(inner)} | nil"
end

defmodule Babel.Field do
  @type value_identifier :: String.t()

  defstruct [:label, :type]

  @type t(type) :: %__MODULE__{
          label: value_identifier(),
          type: type
        }
end

defmodule Babel.ValueIdentifier do
  @moduledoc """
  A validated value identifier.

  Rules:

    * not empty
    * starts with a lowercase ASCII letter
    * remaining chars are lowercase letters, digits, or underscores
  """

  @enforce_keys [:name]
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}

  @type error ::
          :is_empty
          | {:contains_invalid_grapheme, non_neg_integer(), String.t()}

  @lower ?a..?z
  @digit ?0..?9

  @doc """
  Validate a string as an identifier and wrap it in `%Babel.ValueIdentifier{}`.

  Returns:

    * `{:ok, %Babel.ValueIdentifier{}}` if the string is a valid identifier
    * `{:error, :is_empty}` if the string is empty
    * `{:error, {:contains_invalid_grapheme, position, grapheme}}` otherwise
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, error()}
  def new(""), do: {:error, :is_empty}

  def new(<<first::utf8, rest::binary>> = s) do
    if first in @lower do
      validate_rest(s, rest, 1)
    else
      {head, _} = String.next_grapheme(s)
      {:error, {:contains_invalid_grapheme, 0, head}}
    end
  end

  # internal: walk the rest of the string one codepoint at a time
  defp validate_rest(full, <<c::utf8, tail::binary>>, pos)
       when c in @lower or c in @digit or c == ?_ do
    validate_rest(full, tail, pos + 1)
  end

  # end of string: everything was valid
  defp validate_rest(full, <<>>, _pos) do
    {:ok, %__MODULE__{name: full}}
  end

  # anything else is invalid: spaces, uppercase, emoji, etc.
  defp validate_rest(_full, rest, pos) do
    {g, _} = String.next_grapheme(rest)
    {:error, {:contains_invalid_grapheme, pos, g}}
  end

  @doc """
  Turn a `ValueIdentifier` into a type name:

    * converts to PascalCase
    * strips underscores for the final type name
  """
  @spec to_type_name(t()) :: String.t()
  def to_type_name(%__MODULE__{name: name}) do
    name
    |> Kase.convert(:pascal_case)
    |> String.to_charlist()
    |> Enum.reject(&(&1 == ?_))
    |> List.to_string()
  end

  @doc """
  Try to extract a *similar* valid identifier from a free-form string.

  This:

    * trims the string
    * drops leading underscores and digits
    * keeps only lowercase letters, digits and underscores

  Returns:

    * `{:ok, identifier_string}` if something could be salvaged
    * `{:error}` if nothing valid remains
  """
  @spec similar_identifier_string(String.t()) :: {:ok, String.t()} | :error
  def similar_identifier_string(s) do
    proposal =
      s
      |> String.trim()
      |> String.to_charlist()
      |> Enum.drop_while(fn c -> c == ?_ or c in @digit end)
      |> Enum.filter(fn c -> c in @lower or c in @digit or c == ?_ end)
      |> List.to_string()

    case proposal do
      "" -> :error
      _ -> {:ok, proposal}
    end
  end
end
