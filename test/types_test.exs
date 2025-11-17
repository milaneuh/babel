defmodule TypesTest do
  use ExUnit.Case, async: true
  require Calque

  alias Babel.ValueIdentifier
  alias Babel.Type

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

  #
  # Babel.Type.to_guard/2
  #

  test "Babel.Type.to_guard/2 generates correct guards for primitive types" do
    var_name = "value"

    guards = %{
      int: Type.to_guard(Type.int(), var_name),
      float: Type.to_guard(Type.float(), var_name),
      bool: Type.to_guard(Type.bool(), var_name),
      string: Type.to_guard(Type.string(), var_name)
    }

    """
    GIVEN a set of primitive Babel types:

      types = [:int, :float, :bool, :string]
      var_name = #{inspect(var_name)}

    WHEN generating guard expressions:

      guards = %{
        int:   Babel.Type.to_guard(Babel.Type.int(), var_name),
        float: Babel.Type.to_guard(Babel.Type.float(), var_name),
        bool:  Babel.Type.to_guard(Babel.Type.bool(), var_name),
        string: Babel.Type.to_guard(Babel.Type.string(), var_name)
      }

    THEN it should generate the expected guard expressions for each primitive type:

      #{inspect(guards)}
    """
    |> Calque.check()
  end

  test "Babel.Type.to_guard/2 generates correct guards for option types, including nesting" do
    var_name = "value"

    option_int = Type.option(Type.int())
    option_string = Type.option(Type.string())
    nested_option_int = Type.option(Type.option(Type.int()))
    option_array_int = Type.option(Type.array(Type.int()))

    guards = %{
      option_int: Type.to_guard(option_int, var_name),
      option_string: Type.to_guard(option_string, var_name),
      nested_option_int: Type.to_guard(nested_option_int, var_name),
      option_array_int: Type.to_guard(option_array_int, var_name)
    }

    """
    GIVEN several option-based Babel types:

      option_int         = Babel.Type.option(Babel.Type.int())
      option_string      = Babel.Type.option(Babel.Type.string())
      nested_option_int  = Babel.Type.option(Babel.Type.option(Babel.Type.int()))
      option_array_int   = Babel.Type.option(Babel.Type.array(Babel.Type.int()))
      var_name           = #{inspect(var_name)}

    WHEN generating guard expressions for these types:

      guards = %{
        option_int:        Babel.Type.to_guard(option_int, var_name),
        option_string:     Babel.Type.to_guard(option_string, var_name),
        nested_option_int: Babel.Type.to_guard(nested_option_int, var_name),
        option_array_int:  Babel.Type.to_guard(option_array_int, var_name)
      }

    THEN it should generate guard expressions that allow the inner type or nil:

      #{inspect(guards)}
    """
    |> Calque.check()
  end

  test "Babel.Type.to_guard/2 generates guards for array types and ignores inner nesting" do
    var_name = "value"

    array_int = Type.array(Type.int())
    array_option_int = Type.array(Type.option(Type.int()))
    nested_array_bool = Type.array(Type.array(Type.bool()))

    guards = %{
      array_int: Type.to_guard(array_int, var_name),
      array_option_int: Type.to_guard(array_option_int, var_name),
      nested_array_bool: Type.to_guard(nested_array_bool, var_name)
    }

    """
    GIVEN several array-based Babel types, including nested arrays and arrays of options:

      array_int         = Babel.Type.array(Babel.Type.int())
      array_option_int  = Babel.Type.array(Babel.Type.option(Babel.Type.int()))
      nested_array_bool = Babel.Type.array(Babel.Type.array(Babel.Type.bool()))
      var_name          = #{inspect(var_name)}

    WHEN generating guard expressions for these types:

      guards = %{
        array_int:         Babel.Type.to_guard(array_int, var_name),
        array_option_int:  Babel.Type.to_guard(array_option_int, var_name),
        nested_array_bool: Babel.Type.to_guard(nested_array_bool, var_name)
      }

    THEN it should generate array guards that only enforce list-ness at the boundary:

      #{inspect(guards)}
    """
    |> Calque.check()
  end

end
