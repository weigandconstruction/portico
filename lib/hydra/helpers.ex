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
      "/rest/v1.0/bim_files/\\\#{id}"

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

  @doc """
  Checks if an operation has a request body defined.

  ## Examples:

      iex> operation = %Hydra.Spec.Operation{request_body: %{"content" => %{}}, method: "post", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Hydra.Helpers.has_request_body?(operation)
      true

      iex> operation = %Hydra.Spec.Operation{request_body: nil, method: "get", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Hydra.Helpers.has_request_body?(operation)
      false

  """
  @spec has_request_body?(Hydra.Spec.Operation.t()) :: boolean()
  def has_request_body?(%Hydra.Spec.Operation{} = operation) do
    !is_nil(operation.request_body)
  end

  @doc """
  Extracts the content type from an operation's request body.
  Returns the first content type found, or nil if no request body is defined.

  ## Examples:

      iex> operation = %Hydra.Spec.Operation{request_body: %{"content" => %{"application/json" => %{}}}, method: "post", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Hydra.Helpers.request_body_content_type(operation)
      "application/json"

      iex> operation = %Hydra.Spec.Operation{request_body: nil, method: "get", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Hydra.Helpers.request_body_content_type(operation)
      nil

  """
  @spec request_body_content_type(Hydra.Spec.Operation.t()) :: String.t() | nil
  def request_body_content_type(%Hydra.Spec.Operation{} = operation) do
    case operation.request_body do
      %{"content" => content} when is_map(content) ->
        content
        |> Map.keys()
        |> List.first()

      _ ->
        nil
    end
  end
end
