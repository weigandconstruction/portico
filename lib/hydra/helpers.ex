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
    |> String.replace(~r/[()='"",\[\]]/, "")
    |> String.replace(~r/\//, "_")
    |> String.replace(~r/[-:]/, "_")
    |> String.replace("$", "")
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
  Converts a tag string into a module name by transforming it into CamelCase.
  Handles hierarchical tags (separated by / or -) and creates a valid Elixir module name.
  Removes special characters that are not valid in module names.

  ## Examples:

      iex> Hydra.Helpers.tag_to_module_name("Core/Workflows/workflow-tools")
      "CoreWorkflowsWorkflowTools"

      iex> Hydra.Helpers.tag_to_module_name("user-management")
      "UserManagement"

      iex> Hydra.Helpers.tag_to_module_name("Quality & Safety/punch-list")
      "QualitySafetyPunchList"

  """
  @spec tag_to_module_name(String.t()) :: String.t()
  def tag_to_module_name(tag) when is_binary(tag) do
    tag
    |> String.replace(~r/[\/\-_&\s]+/, " ")
    |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
    |> String.split()
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join()
  end

  @doc """
  Converts a tag string into a friendly filename by transforming it into snake_case.
  Similar to tag_to_module_name but for file naming.
  Removes special characters that are not valid in filenames.

  ## Examples:

      iex> Hydra.Helpers.tag_to_filename("Core/Workflows/workflow-tools")
      "core_workflows_workflow_tools"

      iex> Hydra.Helpers.tag_to_filename("Quality & Safety/punch-list")
      "quality_safety_punch_list"

  """
  @spec tag_to_filename(String.t()) :: String.t()
  def tag_to_filename(tag) when is_binary(tag) do
    tag
    |> String.downcase()
    |> String.replace(~r/[\/\-_&\s]+/, "_")
    |> String.replace(~r/[^a-z0-9_]/, "")
    |> String.replace(~r/_+/, "_")
    |> String.trim_leading("_")
    |> String.trim_trailing("_")
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
  Interpolates path parameters in a string using the internal parameter names.
  This ensures that the generated URLs use the snake_case parameter names from the function.

  ## Example:

      iex> path = "/assets/{assetId}/history-services/{historyServiceId}"
      iex> params = [
      ...>   %Hydra.Spec.Parameter{name: "assetId", internal_name: "asset_id", in: "path"},
      ...>   %Hydra.Spec.Parameter{name: "historyServiceId", internal_name: "history_service_id", in: "path"}
      ...> ]
      iex> Hydra.Helpers.interpolated_path_with_params(path, params)
      "/assets/\\\#{asset_id}/history-services/\\\#{history_service_id}"

  """
  @spec interpolated_path_with_params(String.t(), [Parameter.t()]) :: String.t()
  def interpolated_path_with_params(path, parameters)
      when is_binary(path) and is_list(parameters) do
    path_params = Enum.filter(parameters, &(&1.in == "path"))

    Enum.reduce(path_params, path, fn param, acc ->
      String.replace(acc, "{#{param.name}}", "\#{#{param.internal_name}}")
    end)
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
  Returns only the required parameters from a path and operation combination.
  Filters the combined parameters to only include those with `required: true`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.required_parameters(path, operation) |> length()
      1

  """
  @spec required_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def required_parameters(%Path{} = path, %Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(& &1.required)
  end

  @doc """
  Returns only the optional parameters from a path and operation combination.
  Filters the combined parameters to only include those with `required: false`.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.optional_parameters(path, operation) |> length()
      1

  """
  @spec optional_parameters(Path.t(), Operation.t()) :: [Parameter.t()]
  def optional_parameters(%Path{} = path, %Operation{} = operation) do
    function_parameters(path, operation)
    |> Enum.filter(&(not &1.required))
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

  defp extract_schema_parameters(%{"type" => "object", "properties" => properties} = schema)
       when is_map(properties) do
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
  Gets all function parameters formatted for documentation.
  Combines path, query, and header parameters, plus body parameters if present.
  Required parameters are sorted to the top, and optional parameters are documented as being passed via opts.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: [%Hydra.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "string"}, description: "Company ID"}]}
      iex> operation = %Hydra.Spec.Operation{parameters: [%Hydra.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "integer"}, description: "Maximum results"}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Hydra.Helpers.all_parameters_for_docs(path, operation) |> length()
      2

  """
  @spec all_parameters_for_docs(Path.t(), Operation.t()) :: [map()]
  def all_parameters_for_docs(%Path{} = path, %Operation{} = operation) do
    # Get required function parameters
    required_params =
      required_parameters(path, operation)
      |> Enum.map(&format_parameter_for_docs/1)

    # Add body parameter if present
    body_param =
      if has_request_body?(operation) do
        body_params = request_body_parameters(operation)

        [
          %{
            name: "body",
            type: "object",
            description: "Request body parameters",
            required: true,
            nested_params: body_params
          }
        ]
      else
        []
      end

    # Add opts parameter if there are optional parameters
    opts_param =
      if !Enum.empty?(optional_parameters(path, operation)) do
        optional_params =
          optional_parameters(path, operation)
          |> Enum.map(&format_parameter_for_docs/1)

        [
          %{
            name: "opts",
            type: "keyword",
            description: "Optional parameters as keyword list",
            required: false,
            nested_params: optional_params
          }
        ]
      else
        []
      end

    # Combine all parameters
    required_params ++ body_param ++ opts_param
  end

  defp format_parameter_for_docs(%Parameter{} = param) do
    type =
      case param.schema do
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

  @doc """
  Groups operations by their tags. If an operation has multiple tags, it uses the first tag.
  If an operation has no tags, it falls back to using the path as the grouping key.
  Returns a map where keys are tag names and values are lists of {path, operation} tuples.

  ## Examples:

      iex> paths = [%Hydra.Spec.Path{path: "/users", operations: [%Hydra.Spec.Operation{tags: ["user-management"], method: "get"}]}]
      iex> Hydra.Helpers.group_operations_by_tag(paths) |> Map.keys()
      ["user-management"]

  """
  @spec group_operations_by_tag([Path.t()]) :: %{String.t() => [{Path.t(), Operation.t()}]}
  def group_operations_by_tag(paths) when is_list(paths) do
    paths
    |> Enum.flat_map(fn path ->
      Enum.map(path.operations, fn operation ->
        tag =
          case operation.tags do
            [first_tag | _] -> first_tag
            # Fallback to path when no tags
            [] -> path.path
          end

        {tag, {path, operation}}
      end)
    end)
    |> Enum.group_by(fn {tag, _} -> tag end, fn {_, path_operation} -> path_operation end)
  end

  @doc """
  Generates a unique function name for an operation within a tag-based module.
  Combines the HTTP method with a path-based identifier to avoid naming conflicts.

  ## Examples:

      iex> path = %Hydra.Spec.Path{path: "/rest/v1.0/users/{id}"}
      iex> operation = %Hydra.Spec.Operation{method: "get"}
      iex> Hydra.Helpers.function_name_for_operation(path, operation)
      "get_rest_v1_0_users_id"

  """
  @spec function_name_for_operation(Path.t(), Operation.t()) :: String.t()
  def function_name_for_operation(%Path{} = path, %Operation{} = operation) do
    path_part = friendly_name(path.path)
    "#{operation.method}_#{path_part}"
  end

  @doc """
  Converts a JSON schema type to an Elixir type specification string.

  ## Examples:

      iex> Hydra.Helpers.schema_to_typespec(%{"type" => "string"})
      "String.t()"

      iex> Hydra.Helpers.schema_to_typespec(%{"type" => "integer"})
      "integer()"

  """
  @spec schema_to_typespec(map() | nil) :: String.t()
  def schema_to_typespec(nil), do: "any()"
  def schema_to_typespec(%{"type" => "string"}), do: "String.t()"
  def schema_to_typespec(%{"type" => "integer"}), do: "integer()"
  def schema_to_typespec(%{"type" => "number"}), do: "float()"
  def schema_to_typespec(%{"type" => "boolean"}), do: "boolean()"
  def schema_to_typespec(%{"type" => "array"}), do: "list()"
  def schema_to_typespec(%{"type" => "object"}), do: "map()"
  def schema_to_typespec(_), do: "any()"

  @doc """
  Generates the typespec for an API function based on its parameters and operation.

  ## Examples:

      iex> path = %Hydra.Spec.Path{parameters: []}
      iex> operation = %Hydra.Spec.Operation{parameters: [], method: "get", request_body: nil}
      iex> Hydra.Helpers.function_typespec("get_users", path, operation)
      "@spec get_users(Req.Request.t()) :: {:ok, any()} | {:error, Exception.t()}"

  """
  @spec function_typespec(String.t(), Path.t(), Operation.t()) :: String.t()
  def function_typespec(function_name, %Path{} = path, %Operation{} = operation) do
    required_params = required_parameters(path, operation)
    optional_params = optional_parameters(path, operation)
    has_body = has_request_body?(operation)

    # Build parameter types list
    param_types = ["Req.Request.t()"]

    # Add required parameter types
    param_types =
      param_types ++
        Enum.map(required_params, fn param ->
          schema_to_typespec(param.schema)
        end)

    # Add body parameter if present
    param_types =
      if has_body do
        param_types ++ ["map()"]
      else
        param_types
      end

    # Add opts parameter if there are optional parameters
    param_types =
      if !Enum.empty?(optional_params) do
        param_types ++ ["keyword()"]
      else
        param_types
      end

    param_list = Enum.join(param_types, ", ")
    "@spec #{function_name}(#{param_list}) :: {:ok, any()} | {:error, Exception.t()}"
  end
end
