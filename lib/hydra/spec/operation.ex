defmodule Hydra.Spec.Operation do
  defstruct [
    :id,
    :method,
    :summary,
    :description,
    tags: [],
    parameters: [],
    responses: %{},
    security: %{}
  ]

  def parse(operation) do
    parameters = operation["parameters"] || []
    responses = operation["responses"] || %{}

    %__MODULE__{
      id: operation["operationId"],
      method: operation["method"],
      summary: operation["summary"],
      description: operation["description"],
      tags: operation["tags"] || [],
      parameters: Enum.map(parameters, &Hydra.Spec.Parameter.parse/1),
      responses: Enum.map(responses, &Hydra.Spec.Response.parse/1)
    }
  end
end
