defmodule BabelTest do
  alias Babel.ValueIdentifier
  require Calque
  use ExUnit.Case

  # TESTING THE IDENTIFIER FUNCTION
  test "An empty string should return an error" do
    {status, message} = ValueIdentifier.new("")

    """
    I sent an emtpy string to Babel.identifier()

    The status of the response should be an error :
      #{inspect(status)}

    And the message should contain :is_emtpy :
      #{inspect(message)}
    """
    |> Calque.check()
  end

  test "A string starting with a incorrect grapheme should return an error" do
    {status, message} = ValueIdentifier.new("A_string_should_not_start_with_an_uppercase")

    """
    I sent an invalid string "A_string_should_not_start_with_an_uppercase" to Babel.identifier()

    The status of the response should be an error :
      #{inspect(status)}

    And the message should contain a tuple with the :contains_invalid_grapheme error :
      #{inspect(message)}
    """
    |> Calque.check()
  end

  test "A string containing an incorrect grapheme should return an error" do
    {status, message} = ValueIdentifier.new("a_string_should_not_end_with_an_upperscore_letteR")

    """
    I sent an invalid string "a_string_should_not_end_with_an_upperscore_letteR" to Babel.identifier()

    The status of the response should be an error :
      #{inspect(status)}

    And the message should contain a tuple with the :contains_invalid_grapheme error :
      #{inspect(message)}
    """
    |> Calque.check()
  end

  test "A valid string should return an %ValueIdentifier{}" do
    {status, message} = ValueIdentifier.new("valid_identifier_string")

    """
    I sent a valid string "valid_identifier_string" to Babel.identifier()

    The status of the response should be :ok :
      #{inspect(status)}

    And the message should contain a %ValueIdentifier containing the string :
      #{inspect(message)}
    """
    |> Calque.check()
  end
end
