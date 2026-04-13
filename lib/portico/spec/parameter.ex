defmodule Portico.Spec.Parameter do
  @moduledoc """
  Represents a parameter in the Portico specification.

  A parameter is a piece of data that can be passed to an API endpoint.
  It includes details such as the parameter name, location (in, path, query, header, cookie),
  description, schema, content, style, and whether it is required or deprecated.

  ## Parameter Name Normalization

  Parameter names from OpenAPI specs are normalized to valid Elixir identifiers
  for use in generated code. The original name is preserved in the `name` field,
  while the normalized version is stored in `internal_name`.

  Normalization rules (applied in order):

  - `@` → `at_`
  - `$` → `dollar_`
  - `.` → `_`
  - Converted to snake_case via `Macro.underscore/1`
  - `-` → removed
  - `[` → `_`
  - `]` → removed
  - `<=` → `_lte` (less than or equal)
  - `>=` → `_gte` (greater than or equal)
  - `<>` → `_ne` (not equal)
  - `!=` → `_ne` (not equal)
  - `<` → `_lt` (less than)
  - `>` → `_gt` (greater than)
  - `=` → `_eq` (equal)
  - Reserved Elixir keywords get `_` suffix

  ## Examples

      iex> param = Portico.Spec.Parameter.parse(%{"name" => "DateSent<", "in" => "query"})
      iex> param.name
      "DateSent<"
      iex> param.internal_name
      "date_sent_lt"

      iex> param = Portico.Spec.Parameter.parse(%{"name" => "created[gte]", "in" => "query"})
      iex> param.name
      "created[gte]"
      iex> param.internal_name
      "created_gte"

      iex> param = Portico.Spec.Parameter.parse(%{"name" => "user-id", "in" => "path"})
      iex> param.internal_name
      "userid"

      iex> param = Portico.Spec.Parameter.parse(%{"name" => "end", "in" => "query"})
      iex> param.internal_name
      "end_"
  """

  @type t() :: %__MODULE__{
          name: String.t(),
          internal_name: String.t(),
          description: String.t() | nil,
          in: String.t(),
          schema: map() | nil,
          content: map() | nil,
          style: String.t() | nil,
          deprecated: boolean(),
          explode: boolean(),
          allow_reserved: boolean(),
          allow_empty_value: boolean(),
          required: boolean(),
          examples: list()
        }

  defstruct [
    :name,
    :internal_name,
    :description,
    :in,
    :schema,
    :content,
    :style,
    deprecated: false,
    explode: false,
    allow_reserved: false,
    allow_empty_value: false,
    required: false,
    examples: []
  ]

  @doc """
  Parses a parameter from the OpenAPI 3.0 specification.
  This function takes a parameter map and returns a `Portico.Spec.Parameter` struct.
  """
  @spec parse(map()) :: t()
  def parse(parameter) do
    %__MODULE__{
      name: parameter["name"],
      internal_name: normalize_name(parameter["name"]),
      description: parameter["description"],
      in: parameter["in"],
      required: parameter["required"] || false,
      deprecated: parameter["deprecated"] || false,
      style: parameter["style"],
      explode: parameter["explode"] || false,
      allow_reserved: parameter["allowReserved"] || false,
      allow_empty_value: parameter["allowEmptyValue"] || false,
      schema: parameter["schema"],
      content: parameter["content"],
      examples: parameter["examples"]
    }
  end

  defp normalize_name(name) do
    name
    |> String.replace("@", "at_")
    |> String.replace("$", "dollar_")
    |> String.replace(".", "_")
    |> Macro.underscore()
    |> String.replace("-", "")
    |> String.replace("[", "_")
    |> String.replace("]", "")
    |> String.replace("<=", "_lte")
    |> String.replace(">=", "_gte")
    |> String.replace("<>", "_ne")
    |> String.replace("!=", "_ne")
    |> String.replace("<", "_lt")
    |> String.replace(">", "_gt")
    |> String.replace("=", "_eq")
    |> escape_parameter_name()
  end

  defp escape_parameter_name(name) when is_binary(name) do
    reserved_words = [
      "__CALLER__",
      "__DIR__",
      "__ENV__",
      "__FILE__",
      "__MODULE__",
      "__struct__",
      "after",
      "and",
      "catch",
      "do",
      "else",
      "end",
      "false",
      "fn",
      "in",
      "nil",
      "not",
      "or",
      "rescue",
      "true",
      "when"
    ]

    if name in reserved_words do
      "#{name}_"
    else
      name
    end
  end
end
