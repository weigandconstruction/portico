defmodule Hydra.Spec.Response do
  defstruct [
    :type,
    :description,
    headers: %{},
    content: %{},
    links: %{}
  ]

  def parse({type, response}) do
    %__MODULE__{
      type: type,
      description: response["description"],
      headers: response["headers"],
      content: response["content"],
      links: response["links"] || %{}
    }
  end
end
