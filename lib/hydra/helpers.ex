defmodule Hydra.Helpers do
  @spec friendly_name(String.t()) :: String.t()
  def friendly_name(path) when is_binary(path) do
    path
    |> Macro.underscore()
    |> String.replace(~r/[{}]/, "")
    |> String.replace(~r/\//, "_")
    |> String.replace(~r/[-:]/, "_")
    |> String.trim_leading("_")
    |> String.trim_trailing("_")
  end

  @spec module_name(String.t()) :: String.t()
  def module_name(path) do
    path
    |> friendly_name()
    |> Macro.camelize()
  end

  @doc """
  Interpolates path parameters in a string to use Elixir's string interpolation syntax.
  This is useful for generating function names or paths that include dynamic segments.

  ## Example:

      iex> Hydra.Helpers.interpolated_path("/rest/v1.0/bim_files/{id}")
      "/rest/v1.0/bim_files/\#{id}"

  """
  @spec interpolated_path(String.t()) :: String.t()
  def interpolated_path(path) when is_binary(path) do
    path
    |> String.replace(~r/\{(\w+)\}/, "\#{\\g{1}}")
  end

  def function_parameters(%Hydra.Spec.Path{} = path, %Hydra.Spec.Operation{} = operation) do
    (path.parameters ++ operation.parameters)
    |> Enum.uniq_by(& &1.internal_name)
  end

  def query_parameters(%Hydra.Spec.Path{} = path, %Hydra.Spec.Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "query"))
  end

  def header_parameters(%Hydra.Spec.Path{} = path, %Hydra.Spec.Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "header"))
  end

  def path_parameters(%Hydra.Spec.Path{} = path, %Hydra.Spec.Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "path"))
  end

  def cookie_parameters(%Hydra.Spec.Path{} = path, %Hydra.Spec.Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "cookie"))
  end
end
