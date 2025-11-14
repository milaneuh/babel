defmodule Babel.ValueIdentifier do
  @enforce_keys [:name]
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}

  @type error ::
          :is_empty
          | {:contains_invalid_grapheme, non_neg_integer(), String.t()}
end

defmodule Babel do
  alias __MODULE__.ValueIdentifier

  @lower ?a..?z
  @digit ?0..?9

  @doc """
  Validate a string as an identifier.

  A valid identifier:

    * is not empty
    * starts with a lowercase ASCII letter
    * then only contains lowercase letters, digits or underscores

  Returns:

    * `{:ok, %ValueIdentifier{}}` if the string is a valid identifier
    * `{:error, :is_empty}` if the string is empty
    * `{:error, {:contains_invalid_grapheme, position, grapheme}}` if it contains an invalid grapheme
  """
  @spec identifier(String.t()) :: {:ok, ValueIdentifier.t()} | {:error, ValueIdentifier.error()}
  def identifier(""), do: {:error, :is_empty}

  def identifier(<<first::utf8, rest::binary>> = s) do
    if first in @lower do
      validate_rest(s, rest, 1)
    else
      {head, _} = String.next_grapheme(s)
      {:error, {:contains_invalid_grapheme, 0, head}}
    end
  end

  # Walk the rest of the string one codepoint at a time.
  # `pos` is the index of the current grapheme (0-based).
  defp validate_rest(full, <<c::utf8, tail::binary>>, pos)
       when c in @lower or c in @digit or c == ?_ do
    validate_rest(full, tail, pos + 1)
  end

  # End of string: everything was valid.
  defp validate_rest(full, <<>>, _pos) do
    {:ok, %ValueIdentifier{name: full}}
  end

  # Anything else is invalid: spaces, uppercase, emoji, etc.
  defp validate_rest(_full, rest, pos) do
    {g, _} = String.next_grapheme(rest)
    {:error, {:contains_invalid_grapheme, pos, g}}
  end
end
