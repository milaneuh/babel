defmodule TypesTest do
  use ExUnit.Case, async: true
  require Calque

  alias Babel.ValueIdentifier

  #
  # ValueIdentifier.new/1
  #

  test "ValueIdentifier.new/1 with empty string returns an error" do
    result = ValueIdentifier.new("")

    """
    GIVEN I call ValueIdentifier.new/1 with an empty string:

      result = Babel.ValueIdentifier.new("")

    THEN it should return an error tuple:

      #{inspect(result)}
    """
    |> Calque.check()
  end

  test "ValueIdentifier.new/1 rejects an identifier starting with an invalid grapheme" do
    input = "A_string_should_not_start_with_an_uppercase"
    result = ValueIdentifier.new(input)

    """
    GIVEN an invalid identifier starting with an uppercase letter:

      input = #{inspect(input)}

    WHEN calling:

      result = Babel.ValueIdentifier.new(input)

    THEN it should return the error tuple:

      #{inspect(result)}
    """
    |> Calque.check()
  end

  test "ValueIdentifier.new/1 rejects an identifier containing an invalid grapheme later" do
    input = "a_string_should_not_end_with_an_upperscore_letteR"
    result = ValueIdentifier.new(input)

    """
    GIVEN an invalid identifier containing an uppercase letter inside it:

      input = #{inspect(input)}

    WHEN calling:

      result = Babel.ValueIdentifier.new(input)

    THEN it should return the error tuple:

      #{inspect(result)}
    """
    |> Calque.check()
  end

  test "ValueIdentifier.new/1 accepts a correct identifier" do
    input = "valid_identifier_string"
    result = ValueIdentifier.new(input)

    """
    GIVEN a valid identifier:

      input = #{inspect(input)}

    WHEN calling:

      result = Babel.ValueIdentifier.new(input)

    THEN it should return an :ok tuple containing a ValueIdentifier struct:

      #{inspect(result)}
    """
    |> Calque.check()
  end

  #
  # ValueIdentifier.to_type_name/1
  #

  test "ValueIdentifier.to_type_name/1 converts snake_case to PascalCase" do
    input = "my_valid_identifier_name"
    {:ok, id} = ValueIdentifier.new(input)
    type_name = ValueIdentifier.to_type_name(id)

    """
    GIVEN a valid ValueIdentifier:

      #{inspect(id)}

    WHEN converting it to a type name:

      type_name = Babel.ValueIdentifier.to_type_name(id)

    THEN the result should be the PascalCase type name:

      #{inspect(type_name)}
    """
    |> Calque.check()
  end

  #
  # ValueIdentifier.similar_identifier_string/1
  #

  test "ValueIdentifier.similar_identifier_string/1 extracts a usable identifier from noisy input" do
    input = "  __123foo_bar!!  "
    result = ValueIdentifier.similar_identifier_string(input)

    """
    GIVEN a noisy input string:

      #{inspect(input)}

    WHEN extracting a similar identifier:

      result = Babel.ValueIdentifier.similar_identifier_string(input)

    THEN it should return the cleaned identifier:

      #{inspect(result)}
    """
    |> Calque.check()
  end

  test "ValueIdentifier.similar_identifier_string/1 returns :error when nothing valid remains" do
    input = "__123!!"
    result = ValueIdentifier.similar_identifier_string(input)

    """
    GIVEN an input string containing no valid identifier characters:

      #{inspect(input)}

    WHEN extracting a similar identifier:

      result = Babel.ValueIdentifier.similar_identifier_string(input)

    THEN it should return :error:

      #{inspect(result)}
    """
    |> Calque.check()
  end
end

