defmodule Portico.Helpers do
  @moduledoc """
  A collection of helper functions for working with paths and operations in Portico.
  """

  alias Portico.Spec.{Operation, Parameter, Path}

  @doc """
  Converts a path string into a more human-readable format by replacing
  certain characters with underscores and removing braces. This is useful for
  generating friendly names for paths that can be used in filename creation.

  ## Example:

      iex> Portico.Helpers.friendly_name("/rest/v1.0/bim_files/{id}")
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

      iex> Portico.Helpers.module_name("/rest/v1.0/bim_files/{id}")
      "RestV10BimFilesId"

  """
  @spec module_name(String.t()) :: String.t()
  def module_name(path) do
    path
    |> friendly_name()
    |> Macro.camelize()
  end

  @doc """
  Converts a module name to a string suitable for Application.get_env/3.
  Handles dotted module names by converting to snake_case with underscores.

  ## Examples:

      iex> Portico.Helpers.module_to_config_key("Example.Procore")
      "example_procore"

      iex> Portico.Helpers.module_to_config_key("MyAPI")
      "my_api"

  """
  @spec module_to_config_key(String.t()) :: String.t()
  def module_to_config_key(module_name) when is_binary(module_name) do
    module_name
    |> Macro.underscore()
    |> String.replace("/", "_")
  end

  @doc """
  Converts a tag string into a module name by transforming it into CamelCase.
  Handles hierarchical tags (separated by / or -) and creates a valid Elixir module name.
  Removes special characters that are not valid in module names.
  Prefixes with "N" if the result would start with a number.

  ## Examples:

      iex> Portico.Helpers.tag_to_module_name("Core/Workflows/workflow-tools")
      "CoreWorkflowsWorkflowTools"

      iex> Portico.Helpers.tag_to_module_name("user-management")
      "UserManagement"

      iex> Portico.Helpers.tag_to_module_name("Quality & Safety/punch-list")
      "QualitySafetyPunchList"

      iex> Portico.Helpers.tag_to_module_name("1-Click Applications")
      "N1ClickApplications"

  """
  @spec tag_to_module_name(String.t()) :: String.t()
  def tag_to_module_name(tag) when is_binary(tag) do
    module_name =
      tag
      |> String.replace(~r/[\/\-_&\s]+/, " ")
      |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
      |> String.split()
      |> Enum.map_join(&Macro.camelize/1)

    # If the module name starts with a number, prefix it with "N"
    if Regex.match?(~r/^\d/, module_name) do
      "N" <> module_name
    else
      module_name
    end
  end

  @doc """
  Converts a tag string into a friendly filename by transforming it into snake_case.
  Similar to tag_to_module_name but for file naming.
  Removes special characters that are not valid in filenames.
  Prefixes with "n" if the result would start with a number.

  ## Examples:

      iex> Portico.Helpers.tag_to_filename("Core/Workflows/workflow-tools")
      "core_workflows_workflow_tools"

      iex> Portico.Helpers.tag_to_filename("Quality & Safety/punch-list")
      "quality_safety_punch_list"

      iex> Portico.Helpers.tag_to_filename("1-Click Applications")
      "n1_click_applications"

  """
  @spec tag_to_filename(String.t()) :: String.t()
  def tag_to_filename(tag) when is_binary(tag) do
    filename =
      tag
      |> String.downcase()
      |> String.replace(~r/[\/\-_&\s]+/, "_")
      |> String.replace(~r/[^a-z0-9_]/, "")
      |> String.replace(~r/_+/, "_")
      |> String.trim_leading("_")
      |> String.trim_trailing("_")

    # If the filename starts with a number, prefix it with "n"
    if Regex.match?(~r/^\d/, filename) do
      "n" <> filename
    else
      filename
    end
  end

  @doc """
  Interpolates path parameters in a string to use Elixir's string interpolation syntax.
  This is useful for generating function names or paths that include dynamic segments.

  ## Example:

      iex> Portico.Helpers.interpolated_path("/rest/v1.0/bim_files/{id}")
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
      ...>   %Portico.Spec.Parameter{name: "assetId", internal_name: "asset_id", in: "path"},
      ...>   %Portico.Spec.Parameter{name: "historyServiceId", internal_name: "history_service_id", in: "path"}
      ...> ]
      iex> Portico.Helpers.interpolated_path_with_params(path, params)
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.function_parameters(path, operation) |> length()
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.query_parameters(path, operation) |> length()
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "Authorization", internal_name: "authorization", in: "header", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.header_parameters(path, operation) |> length()
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.required_parameters(path, operation) |> length()
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: []}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.optional_parameters(path, operation) |> length()
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

      iex> operation = %Portico.Spec.Operation{request_body: %{"content" => %{}}, method: "post", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Portico.Helpers.has_request_body?(operation)
      true

      iex> operation = %Portico.Spec.Operation{request_body: nil, method: "get", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Portico.Helpers.has_request_body?(operation)
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
      iex> operation = %Portico.Spec.Operation{request_body: request_body, method: "post", parameters: [], responses: %{}, security: %{}, tags: []}
      iex> Portico.Helpers.request_body_parameters(operation) |> length()
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

      iex> path = %Portico.Spec.Path{parameters: [%Portico.Spec.Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "string"}, description: "Company ID"}]}
      iex> operation = %Portico.Spec.Operation{parameters: [%Portico.Spec.Parameter{name: "limit", internal_name: "limit", in: "query", required: false, deprecated: false, explode: false, allow_reserved: false, allow_empty_value: false, examples: [], schema: %{"type" => "integer"}, description: "Maximum results"}], method: "get", responses: %{}, security: %{}, tags: [], request_body: nil}
      iex> Portico.Helpers.all_parameters_for_docs(path, operation) |> length()
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
        %{"type" => "array", "items" => %{"type" => "integer"}} ->
          "[integer()]"

        %{"type" => "array", "items" => %{"type" => item_type}} ->
          "[#{item_type}]"

        %{"type" => "array"} ->
          "list()"

        %{"type" => type} ->
          type

        _ ->
          "string"
      end

    %{
      name: param.internal_name,
      original_name: param.name,
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

      iex> paths = [%Portico.Spec.Path{path: "/users", operations: [%Portico.Spec.Operation{tags: ["user-management"], method: "get"}]}]
      iex> Portico.Helpers.group_operations_by_tag(paths) |> Map.keys()
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

      iex> path = %Portico.Spec.Path{path: "/rest/v1.0/users/{id}"}
      iex> operation = %Portico.Spec.Operation{method: "get"}
      iex> Portico.Helpers.function_name_for_operation(path, operation)
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

      iex> Portico.Helpers.schema_to_typespec(%{"type" => "string"})
      "String.t()"

      iex> Portico.Helpers.schema_to_typespec(%{"type" => "integer"})
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

      iex> path = %Portico.Spec.Path{parameters: []}
      iex> operation = %Portico.Spec.Operation{parameters: [], method: "get", request_body: nil}
      iex> Portico.Helpers.function_typespec("get_users", path, operation)
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

  @doc """
  Gets the response model module name for an operation if available.
  Returns nil if no model is found or models are not generated.

  Since schemas might be expanded inline (without $ref), we try multiple approaches:
  1. Look for a $ref in the response schema
  2. Use the operation_id to find inline response models (e.g., GetPostResponse)
  """
  @spec get_response_model(Operation.t(), String.t(), boolean()) :: String.t() | nil
  def get_response_model(
        %Operation{responses: responses, id: operation_id},
        module_base,
        generate_models
      )
      when generate_models and is_binary(operation_id) do
    # First try to extract a ref-based model name
    case Portico.ModelHelpers.extract_response_schema(responses) do
      nil ->
        # If no ref found, check if there's a 2xx response with inline schema
        # and use the operation_id to generate the model name
        success_response =
          Enum.find(responses, fn {status, _} ->
            String.starts_with?(to_string(status), "2")
          end)

        case success_response do
          {_, %Portico.Spec.Response{content: %{"application/json" => %{"schema" => schema}}}}
          when is_map(schema) and map_size(schema) > 0 ->
            # Generate model name from operation_id (e.g., getPost -> GetPostResponse)
            model_name = Portico.ModelHelpers.schema_to_module_name(operation_id <> "_response")
            "#{module_base}.Models.#{model_name}"

          _ ->
            nil
        end

      schema_name ->
        model_name = Portico.ModelHelpers.schema_to_module_name(schema_name)
        "#{module_base}.Models.#{model_name}"
    end
  end

  def get_response_model(_, _, _), do: nil
end
