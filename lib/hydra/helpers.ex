defmodule Hydra.Helpers do
  @moduledoc """
  A collection of helper functions for working with paths and operations in Hydra.
  """

  alias Hydra.Spec.{Operation, Parameter, Path}

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

  @doc """
  Returns all unique parameters for a given path and operation combination.
  Combines path-level and operation-level parameters, removing duplicates by internal_name.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.function_parameters(path, operation) |> length()
      2

  """
  @spec function_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def function_parameters(%Path{} = path, %Operation{} = operation) do
    (path.parameters ++ operation.parameters)
    |> Enum.uniq_by(& &1.internal_name)
  end

  @doc """
  Returns only the query parameters from a path and operation combination.
  Filters the combined parameters to only include those with `in: "query"`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.query_parameters(path, operation) |> length()
      1

  """
  @spec query_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def query_parameters(%Path{} = path, %Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "query"))
  end

  @doc """
  Returns only the header parameters from a path and operation combination.
  Filters the combined parameters to only include those with `in: "header"`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "Authorization", internal_name: "authorization", in: "header", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.header_parameters(path, operation) |> length()
      1

  """
  @spec header_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def header_parameters(%Path{} = path, %Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "header"))
  end

  @doc """
  Returns only the path parameters from a path and operation combination.
  Filters the combined parameters to only include those with `in: "path"`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.path_parameters(path, operation) |> length()
      1

  """
  @spec path_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def path_parameters(%Path{} = path, %Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(&1.in == "path"))
  end

  @doc """
  Returns only the cookie parameters from a path and operation combination.
  Filters the combined parameters to only include those with `in: "cookie"`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "session_id", internal_name: "session_id", in: "cookie", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.cookie_parameters(path, operation) |> length()
      1

  """
  @spec cookie_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def cookie_parameters(%Path{} = path, %Operation{} = operation) do
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
  @spec has_request_body?(Operation.t()) :: boolean()
  def has_request_body?(%Operation{} = operation) do
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
  @spec request_body_content_type(Operation.t()) :: String.t() | nil
  def request_body_content_type(%Operation{} = operation) do
    case operation.request_body do
      %{"content" => content} when is_map(content) ->
        content
        |> Map.keys()
        |> List.first()

      _ ->
        nil
    end
  end

  @doc """
  Extracts body parameters from an operation's request body schema.
  Returns a list of parameter maps with name, type, description, and required status.
  Required parameters are sorted to the top.

  ## Examples:

      iex> request_body = %{"content" => %{"application/json" => %{"schema" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string", "description" => "User name"}, "age" => %{"type" => "integer"}}, "required" => ["name"]}}}}
      iex> operation = %Hydra.Spec.Operation{request_body: request_body, method: "post", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Hydra.Helpers.request_body_parameters(operation) |> length()
      2

  """
  @spec request_body_parameters(Operation.t()) :: [map()]
  def request_body_parameters(%Operation{} = operation) do
    case operation.request_body do
      %{"content" => content} when is_map(content) ->
        content
        |> Map.values()
        |> List.first()
        |> case do
          %{"schema" => schema} -> extract_schema_parameters(schema)
          _ -> []
        end

      _ ->
        []
    end
    |> Enum.sort_by(& &1.required, :desc)
  end

  defp extract_schema_parameters(%{"type" => "object", "properties" => properties} = schema) when is_map(properties) do
    required_fields = Map.get(schema, "required", [])

    properties
    |> Enum.map(fn {name, prop} ->
      %{
        name: name,
        type: Map.get(prop, "type", "unknown"),
        description: Map.get(prop, "description"),
        required: name in required_fields
      }
    end)
  end

  defp extract_schema_parameters(_), do: []

  @doc """
  Formats query parameters for documentation.
  Returns a list of parameter documentation strings with name, type, description, and required status.
  Required parameters are sorted to the top.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: []}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "integer"}, description: "Maximum number of results"}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.query_parameters_for_docs(path, operation) |> length()
      1

  """
  @spec query_parameters_for_docs(Path.t(), Operation.t()) :: [map()]
  def query_parameters_for_docs(%Path{} = path, %Operation{} = operation) do
    query_parameters(path, operation)
    |> Enum.map(&format_parameter_for_docs/1)
    |> Enum.sort_by(& &1.required, :desc)
  end

  @doc """
  Formats header parameters for documentation.
  Returns a list of parameter documentation strings with name, type, description, and required status.
  Required parameters are sorted to the top.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "Authorization", internal_name: "authorization", in: "header", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "string"}, description: "Bearer token"}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.header_parameters_for_docs(path, operation) |> length()
      1

  """
  @spec header_parameters_for_docs(Path.t(), Operation.t()) :: [map()]
  def header_parameters_for_docs(%Path{} = path, %Operation{} = operation) do
    header_parameters(path, operation)
    |> Enum.map(&format_parameter_for_docs/1)
    |> Enum.sort_by(& &1.required, :desc)
  end

  @doc """
  Gets all function parameters formatted for documentation.
  Combines path, query, and header parameters, plus body parameters if present.
  Required parameters are sorted to the top.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "string"}, description: "Company ID"}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "integer"}, description: "Maximum results"}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.all_parameters_for_docs(path, operation) |> length()
      2

  """
  @spec all_parameters_for_docs(Path.t(), Operation.t()) :: [map()]
  def all_parameters_for_docs(%Path{} = path, %Operation{} = operation) do
    # Get all function parameters (path, query, header, cookie)
    function_params = function_parameters(path, operation)
                     |> Enum.map(&format_parameter_for_docs/1)

    # Add body parameter if present
    body_param = if has_request_body?(operation) do
      body_params = request_body_parameters(operation)
      [%{
        name: "body",
        type: "object",
        description: "Request body parameters",
        required: true,
        nested_params: body_params
      }]
    else
      []
    end

    # Combine and sort by required status
    (function_params ++ body_param)
    |> Enum.sort_by(& &1.required, :desc)
  end

  defp format_parameter_for_docs(%Parameter{} = param) do
    type = case param.schema do
      %{"type" => type} -> type
      _ -> "string"
    end

    %{
      name: param.internal_name,
      type: type,
      description: param.description,
      required: param.required
    }
  end
end
