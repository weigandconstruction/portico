defmodule Hydra.Spec.Parameter do
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
    |> Macro.underscore()
    |> String.replace("-", "")
    |> String.replace("[", "_")
    |> String.replace("]", "")
    |> escape_parameter_name()
  end

  @doc """
  Escape parameter names that are reserved words in Elixir.

  ## Reserved words:
  - `__CALLER__`
  - `__DIR__`
  - `__ENV__`
  - `__FILE__`
  - `__MODULE__`
  - `__struct__`
  - `after`
  - `and`
  - `catch`
  - `do`
  - `else`
  - `end`
  - `false`
  - `fn`
  - `in`
  - `nil`
  - `not`
  - `or`
  - `rescue`
  - `true`
  - `when`

  ## Example:

      iex> Hydra.Spec.Path.escape_parameter_name("id")
      "id"

      iex> Hydra.Spec.Path.escape_parameter_name("do")
      "do_"

  """
  def escape_parameter_name(name) when is_binary(name) do
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
