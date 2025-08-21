defmodule Portico.Spec.Schema do
  @moduledoc """
  Represents and parses OpenAPI schema definitions.
  Handles various schema types including objects, arrays, primitives, and composite types (allOf, oneOf, anyOf).
  """

  @type t() :: %__MODULE__{
          type: String.t() | nil,
          format: String.t() | nil,
          description: String.t() | nil,
          properties: %{String.t() => t()} | nil,
          required: [String.t()] | nil,
          items: t() | nil,
          enum: [any()] | nil,
          example: any() | nil,
          default: any() | nil,
          nullable: boolean() | nil,
          all_of: [t()] | nil,
          one_of: [t()] | nil,
          any_of: [t()] | nil,
          discriminator: map() | nil,
          additional_properties: boolean() | t() | nil,
          ref: String.t() | nil,
          title: String.t() | nil
        }

  defstruct [
    :type,
    :format,
    :description,
    :properties,
    :required,
    :items,
    :enum,
    :example,
    :default,
    :nullable,
    :all_of,
    :one_of,
    :any_of,
    :discriminator,
    :additional_properties,
    :ref,
    :title
  ]

  @doc """
  Parses a schema definition from an OpenAPI specification.
  Handles both inline schemas and $ref references.
  """
  @spec parse(map() | nil) :: t() | nil
  def parse(nil), do: nil

  def parse(schema) when is_map(schema) do
    %__MODULE__{
      type: schema["type"],
      format: schema["format"],
      description: schema["description"],
      properties: parse_properties(schema["properties"]),
      required: schema["required"],
      items: parse(schema["items"]),
      enum: schema["enum"],
      example: schema["example"],
      default: schema["default"],
      nullable: schema["nullable"],
      all_of: parse_list(schema["allOf"]),
      one_of: parse_list(schema["oneOf"]),
      any_of: parse_list(schema["anyOf"]),
      discriminator: schema["discriminator"],
      additional_properties: parse_additional_properties(schema["additionalProperties"]),
      ref: schema["$ref"],
      title: schema["title"]
    }
  end

  defp parse_properties(nil), do: nil

  defp parse_properties(properties) when is_map(properties) do
    properties
    |> Enum.map(fn {key, value} -> {key, parse(value)} end)
    |> Map.new()
  end

  defp parse_list(nil), do: nil
  defp parse_list(list) when is_list(list), do: Enum.map(list, &parse/1)

  defp parse_additional_properties(nil), do: nil
  defp parse_additional_properties(true), do: true
  defp parse_additional_properties(false), do: false
  defp parse_additional_properties(schema) when is_map(schema), do: parse(schema)

  @doc """
  Extracts all schemas from the components section of an OpenAPI spec.
  Returns a map where keys are schema names and values are parsed Schema structs.
  """
  @spec extract_schemas(map() | struct()) :: %{String.t() => t()}
  def extract_schemas(%Portico.Spec{components: nil}), do: %{}

  def extract_schemas(%Portico.Spec{components: components}) do
    extract_schemas_from_components(components)
  end

  def extract_schemas(spec) when is_map(spec) do
    case spec["components"] do
      nil -> %{}
      components -> extract_schemas_from_components(components)
    end
  end

  defp extract_schemas_from_components(components) when is_map(components) do
    case components["schemas"] do
      nil ->
        %{}

      schemas when is_map(schemas) ->
        schemas
        |> Enum.map(fn {name, schema} -> {name, parse(schema)} end)
        |> Map.new()
    end
  end

  defp extract_schemas_from_components(_), do: %{}

  @doc """
  Resolves a schema reference to its name.
  For example: "#/components/schemas/User" -> "User"
  """
  @spec resolve_ref_name(String.t()) :: String.t() | nil
  def resolve_ref_name("#/components/schemas/" <> name), do: name
  def resolve_ref_name(_), do: nil

  @doc """
  Determines if a schema represents a simple type (not an object or array).
  """
  @spec simple_type?(t()) :: boolean()
  def simple_type?(%__MODULE__{type: type})
      when type in ["string", "integer", "number", "boolean"],
      do: true

  def simple_type?(_), do: false

  @doc """
  Determines if a schema represents an object type.
  """
  @spec object_type?(t()) :: boolean()
  def object_type?(%__MODULE__{type: "object"}), do: true
  def object_type?(%__MODULE__{properties: props}) when not is_nil(props), do: true
  def object_type?(_), do: false

  @doc """
  Determines if a schema represents an array type.
  """
  @spec array_type?(t()) :: boolean()
  def array_type?(%__MODULE__{type: "array"}), do: true
  def array_type?(_), do: false

  @doc """
  Gets the effective type of a schema, considering references and composite types.
  """
  @spec effective_type(t()) :: String.t() | nil
  def effective_type(%__MODULE__{type: type}) when not is_nil(type), do: type
  def effective_type(%__MODULE__{ref: ref}) when not is_nil(ref), do: "ref"
  def effective_type(%__MODULE__{all_of: schemas}) when not is_nil(schemas), do: "object"
  def effective_type(%__MODULE__{one_of: _}), do: "union"
  def effective_type(%__MODULE__{any_of: _}), do: "union"
  def effective_type(%__MODULE__{properties: props}) when not is_nil(props), do: "object"
  def effective_type(_), do: nil

  @doc """
  Extracts inline schemas from all responses in an OpenAPI spec.
  Returns a map where keys are generated schema names and values are parsed Schema structs.
  """
  @spec extract_inline_schemas(map() | struct()) :: %{String.t() => t()}
  def extract_inline_schemas(%Portico.Spec{paths: paths}) when is_list(paths) do
    paths
    |> Enum.flat_map(&extract_schemas_from_path/1)
    |> Map.new()
  end

  def extract_inline_schemas(_), do: %{}

  defp extract_schemas_from_path(%Portico.Spec.Path{path: path, operations: operations}) do
    operations
    |> Enum.flat_map(fn operation ->
      extract_schemas_from_operation(path, operation)
    end)
  end

  defp extract_schemas_from_operation(path, %Portico.Spec.Operation{
         method: method,
         id: operation_id,
         responses: responses,
         request_body: request_body
       }) do
    response_schemas = extract_schemas_from_responses(path, method, operation_id, responses)
    request_schemas = extract_schemas_from_request_body(path, method, operation_id, request_body)

    response_schemas ++ request_schemas
  end

  defp extract_schemas_from_responses(path, method, operation_id, responses)
       when is_map(responses) do
    responses
    |> Enum.flat_map(fn {status_code, response} ->
      case response do
        %Portico.Spec.Response{content: content} ->
          extract_schemas_from_content(path, method, operation_id, status_code, content)

        _ ->
          []
      end
    end)
  end

  defp extract_schemas_from_responses(_, _, _, _), do: []

  defp extract_schemas_from_request_body(path, method, operation_id, request_body)
       when is_map(request_body) do
    case request_body["content"] do
      %{"application/json" => %{"schema" => schema}} when is_map(schema) ->
        if should_extract_schema?(schema) do
          name = generate_schema_name(path, method, operation_id, "Request")
          [{name, parse(schema)}]
        else
          []
        end

      _ ->
        []
    end
  end

  defp extract_schemas_from_request_body(_, _, _, _), do: []

  defp extract_schemas_from_content(path, method, operation_id, status_code, content)
       when is_map(content) do
    case content["application/json"] do
      %{"schema" => schema} when is_map(schema) ->
        if should_extract_schema?(schema) and String.starts_with?(to_string(status_code), "2") do
          suffix = if status_code == "200", do: "Response", else: "Response#{status_code}"
          name = generate_schema_name(path, method, operation_id, suffix)
          [{name, parse(schema)}]
        else
          []
        end

      _ ->
        []
    end
  end

  defp extract_schemas_from_content(_, _, _, _, _), do: []

  defp should_extract_schema?(schema) when is_map(schema) do
    # Extract if it's an object with properties (not just a ref or primitive type)
    case schema do
      %{"type" => "object", "properties" => props} when is_map(props) and map_size(props) > 0 ->
        true

      %{"properties" => props} when is_map(props) and map_size(props) > 0 ->
        true

      _ ->
        false
    end
  end

  defp generate_schema_name(path, method, operation_id, suffix) do
    # Use operation_id if available, otherwise generate from path and method
    base_name =
      if operation_id do
        operation_id
      else
        # Convert path like "/users/{id}/posts" to "UsersIdPosts"
        path
        |> String.split("/")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map_join(fn segment ->
          segment
          |> String.replace(~r/[{}]/, "")
          |> String.replace(~r/[-_]/, " ")
          |> String.split()
          |> Enum.map_join(&String.capitalize/1)
        end)
        |> then(fn name -> "#{String.capitalize(method)}#{name}" end)
      end

    "#{base_name}#{suffix}"
  end
end
