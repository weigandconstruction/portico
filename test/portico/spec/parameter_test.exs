defmodule Portico.Spec.ParameterTest do
  use ExUnit.Case, async: true

  alias Portico.Spec.Parameter

  describe "parse/1" do
    test "parses a minimal parameter" do
      input = %{
        "name" => "id",
        "in" => "path"
      }

      param = Parameter.parse(input)

      assert param.name == "id"
      assert param.internal_name == "id"
      assert param.in == "path"
      assert param.description == nil
      assert param.required == false
      assert param.deprecated == false
      assert param.style == nil
      assert param.explode == false
      assert param.allow_reserved == false
      assert param.allow_empty_value == false
      assert param.schema == nil
      assert param.content == nil
      assert param.examples == nil
    end

    test "parses a complete parameter with all fields" do
      input = %{
        "name" => "user-id",
        "in" => "query",
        "description" => "Unique identifier for the user",
        "required" => true,
        "deprecated" => true,
        "style" => "form",
        "explode" => true,
        "allowReserved" => true,
        "allowEmptyValue" => true,
        "schema" => %{
          "type" => "integer",
          "minimum" => 1,
          "maximum" => 999_999
        },
        "content" => %{
          "application/json" => %{
            "schema" => %{"type" => "string"}
          }
        },
        "examples" => %{
          "example1" => %{
            "value" => 123
          }
        }
      }

      param = Parameter.parse(input)

      assert param.name == "user-id"
      assert param.internal_name == "userid"
      assert param.in == "query"
      assert param.description == "Unique identifier for the user"
      assert param.required == true
      assert param.deprecated == true
      assert param.style == "form"
      assert param.explode == true
      assert param.allow_reserved == true
      assert param.allow_empty_value == true
      assert param.schema == %{"type" => "integer", "minimum" => 1, "maximum" => 999_999}
      assert param.content == %{"application/json" => %{"schema" => %{"type" => "string"}}}
      assert param.examples == %{"example1" => %{"value" => 123}}
    end

    test "handles default values for boolean fields" do
      input = %{
        "name" => "test",
        "in" => "query"
      }

      param = Parameter.parse(input)

      assert param.required == false
      assert param.deprecated == false
      assert param.explode == false
      assert param.allow_reserved == false
      assert param.allow_empty_value == false
    end

    test "normalizes parameter names correctly" do
      test_cases = [
        {"simple", "simple"},
        {"camelCase", "camel_case"},
        {"PascalCase", "pascal_case"},
        {"kebab-case", "kebabcase"},
        {"snake_case", "snake_case"},
        {"with.dots", "with/dots"},
        {"with[brackets]", "with_brackets"},
        {"with-multiple-dashes", "withmultipledashes"},
        {"Mixed-Case_and.dots[brackets]", "mixed_case_and/dots_brackets"},
        {"filters[origin_id]", "filters_origin_id"},
        {"filters[search]", "filters_search"},
        {"filters[created_at]", "filters_created_at"},
        {"filters[updated_at]", "filters_updated_at"},
        {"filters[standard_cost_code_id][]", "filters_standard_cost_code_id_"},
        {"filters[trade_id][]", "filters_trade_id_"},
        {"filters[id][]", "filters_id_"},
        {"filters[parent_id][]", "filters_parent_id_"}
      ]

      for {input_name, expected_internal} <- test_cases do
        input = %{"name" => input_name, "in" => "query"}
        param = Parameter.parse(input)

        assert param.name == input_name
        assert param.internal_name == expected_internal
      end
    end

    test "escapes Elixir reserved words" do
      test_cases = [
        {"__CALLER__", "__caller__"},
        {"__DIR__", "__dir__"},
        {"__ENV__", "__env__"},
        {"__FILE__", "__file__"},
        {"__MODULE__", "__module__"},
        {"__struct__", "__struct___"},
        {"after", "after_"},
        {"and", "and_"},
        {"catch", "catch_"},
        {"do", "do_"},
        {"else", "else_"},
        {"end", "end_"},
        {"false", "false_"},
        {"fn", "fn_"},
        {"in", "in_"},
        {"nil", "nil_"},
        {"not", "not_"},
        {"or", "or_"},
        {"rescue", "rescue_"},
        {"true", "true_"},
        {"when", "when_"}
      ]

      for {reserved_word, expected_internal} <- test_cases do
        input = %{"name" => reserved_word, "in" => "query"}
        param = Parameter.parse(input)

        assert param.name == reserved_word
        assert param.internal_name == expected_internal
      end
    end

    test "does not escape non-reserved words" do
      non_reserved_words = [
        "user",
        "id",
        "name",
        "email",
        "password",
        "token",
        "api",
        "version",
        "limit",
        "offset",
        "page",
        "size",
        "filter",
        "sort",
        "order"
      ]

      for word <- non_reserved_words do
        input = %{"name" => word, "in" => "query"}
        param = Parameter.parse(input)

        assert param.name == word
        assert param.internal_name == word
      end
    end

    test "handles different parameter locations" do
      locations = ["query", "header", "path", "cookie"]

      for location <- locations do
        input = %{"name" => "test", "in" => location}
        param = Parameter.parse(input)

        assert param.in == location
      end
    end

    test "handles complex schema objects" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer", "minimum" => 0}
        },
        "required" => ["name"],
        "additionalProperties" => false
      }

      input = %{
        "name" => "user",
        "in" => "query",
        "schema" => schema
      }

      param = Parameter.parse(input)

      assert param.schema == schema
    end

    test "handles multiple content types" do
      content = %{
        "application/json" => %{
          "schema" => %{"type" => "string"}
        },
        "application/xml" => %{
          "schema" => %{"type" => "string"}
        },
        "text/plain" => %{
          "schema" => %{"type" => "string"}
        }
      }

      input = %{
        "name" => "data",
        "in" => "query",
        "content" => content
      }

      param = Parameter.parse(input)

      assert param.content == content
    end

    test "handles multiple examples" do
      examples = %{
        "simple" => %{
          "summary" => "A simple example",
          "value" => "hello"
        },
        "complex" => %{
          "summary" => "A complex example",
          "value" => %{
            "key1" => "value1",
            "key2" => 42
          }
        }
      }

      input = %{
        "name" => "example_param",
        "in" => "query",
        "examples" => examples
      }

      param = Parameter.parse(input)

      assert param.examples == examples
    end

    test "handles nil and missing values gracefully" do
      input = %{
        "name" => "test",
        "in" => "query",
        "description" => nil,
        "schema" => nil,
        "content" => nil,
        "style" => nil,
        "examples" => nil
      }

      param = Parameter.parse(input)

      assert param.name == "test"
      assert param.in == "query"
      assert param.description == nil
      assert param.schema == nil
      assert param.content == nil
      assert param.style == nil
      assert param.examples == nil
    end
  end
end
