defmodule Hydra.Path do
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
      parameters: Enum.map(parameters, &Hydra.Parameter.parse/1)
    }
  end

  def friendly_name(%__MODULE__{path: path}) do
    path
    |> Macro.underscore()
    |> String.replace(~r/[{}]/, "")
    |> String.replace(~r/\//, "_")
    |> String.replace(~r/[-:]/, "_")
    |> String.trim_leading("_")
    |> String.trim_trailing("_")
  end

  def module_name(%__MODULE__{} = path) do
    path
    |> friendly_name()
    |> Macro.camelize()
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
        [Hydra.Operation.parse(operation) | acc]
      else
        acc
      end
    end)
  end
end
