defmodule Portico.Spec.Operation do
  @moduledoc """
  Represents an operation in the Portico specification.
  An operation is a single API endpoint that can be invoked with a specific HTTP method.

  It includes details such as the operation ID, summary, description, parameters, responses, and security requirements.
  """

  @type t() :: %__MODULE__{
          id: String.t() | nil,
          method: String.t(),
          summary: String.t() | nil,
          description: String.t() | nil,
          tags: [String.t()],
          parameters: [Portico.Spec.Parameter.t()],
          responses: %{String.t() => Portico.Spec.Response.t()},
          security: map(),
          request_body: map() | nil
        }

  defstruct [
    :id,
    :method,
    :summary,
    :description,
    tags: [],
    parameters: [],
    responses: %{},
    security: %{},
    request_body: nil
  ]

  @doc """
  Parses an operation from the OpenAPI 3.0 specification.
  """
  @spec parse(map()) :: t()
  def parse(operation) do
    parameters = operation["parameters"] || []
    responses = operation["responses"] || %{}

    %__MODULE__{
      id: operation["operationId"],
      method: operation["method"],
      summary: operation["summary"],
      description: operation["description"],
      tags: operation["tags"] || [],
      parameters: Enum.map(parameters, &Portico.Spec.Parameter.parse/1),
      responses:
        Map.new(responses, fn {status_code, response} ->
          {status_code, Portico.Spec.Response.parse(response)}
        end),
      security: operation["security"] || %{},
      request_body: operation["requestBody"]
    }
  end
end
