defmodule Hydra.Parameter do
  defstruct [
    :name,
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
end
