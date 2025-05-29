defmodule Hydra.Spec.Path do
  @moduledoc """
  Represents a path in the Hydra specification.
  A path is a specific endpoint in the API that can be accessed using various HTTP methods.
  It includes the path string, a list of operations (HTTP methods), and parameters that can be used with every
  operation on that path.

  Each operation can have its own parameters, but the path can also define parameters that are common to all operations.

  See Hydra.Spec.Operation and Hydra.Spec.Parameter for more details on operations and parameters.
  """

  @type t() :: %__MODULE__{
          path: String.t(),
          operations: [Hydra.Spec.Operation.t()],
          parameters: [Hydra.Spec.Parameter.t()]
        }

  defstruct [
    :path,
    operations: [],
    parameters: []
  ]

  @doc """
  Parses a path from the OpenAPI 3.0 specification.

  This function takes a tuple with the path string and a map containing the operations and parameters,
  and returns a `Hydra.Spec.Path` struct.
  """
  @spec parse({String.t(), map()}) :: t()
  def parse({path, body}) do
    parameters = body["parameters"] || []

    %__MODULE__{
      path: path,
      operations: parse_operations(body),
      parameters: Enum.map(parameters, &Hydra.Spec.Parameter.parse/1)
    }
  end

  defp valid_methods do
    ~w(get post put delete patch options head trace)
  end

  defp parse_operations(body) do
    Enum.reduce(valid_methods(), [], fn method, acc ->
      if Map.has_key?(body, method) do
        # Get the operation for the method
        operation = body[method]
        operation = Map.put(operation, "method", method)
        [Hydra.Spec.Operation.parse(operation) | acc]
      else
        acc
      end
    end)
  end
end
