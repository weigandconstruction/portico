defmodule Hydra.Spec.Path do
  defstruct [
    :path,
    operations: [],
    parameters: []
  ]

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
