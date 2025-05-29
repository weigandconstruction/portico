defmodule Hydra.Helpers do
  @moduledoc """
  A collection of helper functions for working with paths and operations in Hydra.
  """

  @doc """
  Converts a path string into a more human-readable format by replacing
  certain characters with underscores and removing braces. This is useful for
  generating friendly names for paths that can be used in filename creation.

  ## Example:

      iex> Hydra.Helpers.friendly_name("/rest/v1.0/bim_files/{id}")
      "rest_v1_0_bim_files_id"

  """
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

  @doc """
  Converts a path string into a module name by transforming it into CamelCase.
  This is useful for generating module names from paths, ensuring that the
  resulting name is valid in Elixir.

  ## Example:

      iex> Hydra.Helpers.module_name("/rest/v1.0/bim_files/{id}")
      "RestV10BimFilesId"

  """
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
