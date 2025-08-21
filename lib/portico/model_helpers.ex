defmodule Portico.ModelHelpers do
  @moduledoc """
  Helper functions for generating Elixir models from OpenAPI schemas.
  """

  alias Portico.Spec.Schema

  @doc """
  Converts a schema name to a valid Elixir module name.

  ## Examples

      iex> Portico.ModelHelpers.schema_to_module_name("UserResponse")
      "UserResponse"
      
      iex> Portico.ModelHelpers.schema_to_module_name("user-response")
      "UserResponse"
      
      iex> Portico.ModelHelpers.schema_to_module_name("user_response")
      "UserResponse"
  """
  @spec schema_to_module_name(String.t()) :: String.t()
  def schema_to_module_name(name) do
    name
    |> String.replace(~r/[-_]/, " ")
    |> String.split()
    |> Enum.map_join(&Macro.camelize/1)
  end

  @doc """
  Converts a property name from the OpenAPI spec (often camelCase) to Elixir snake_case.
  Also sanitizes the name to be a valid Elixir atom.

  ## Examples

      iex> Portico.ModelHelpers.property_to_field_name("userName")
      "user_name"
      
      iex> Portico.ModelHelpers.property_to_field_name("id")
      "id"
      
      iex> Portico.ModelHelpers.property_to_field_name("custom_field_%{custom_field_definition_id}")
      "custom_field_custom_field_definition_id"
  """
  @spec property_to_field_name(String.t()) :: String.t()
  def property_to_field_name(name) do
    # Handle special cases
    case name do
      # Special case for ellipsis
      "..." ->
        "extra_fields"

      _ ->
        name
        # Remove or replace invalid characters for Elixir atoms
        |> String.replace(~r/[%{}\(\)\[\]\.:\/\\]/, "_")
        # Collapse multiple underscores
        |> String.replace(~r/_+/, "_")
        # Remove leading/trailing underscores
        |> String.trim("_")
        # Handle empty result
        |> then(fn n -> if n == "", do: "field", else: n end)
        |> Macro.underscore()
    end
  end

  @doc """
  Generates a typespec string for a schema.
  """
  @spec schema_to_typespec(Schema.t() | nil, map()) :: String.t()
  def schema_to_typespec(nil, _schemas), do: "any()"

  def schema_to_typespec(%Schema{ref: ref}, _schemas) when not is_nil(ref) do
    case Schema.resolve_ref_name(ref) do
      nil ->
        "any()"

      name ->
        module_name = schema_to_module_name(name)
        "Models.#{module_name}.t()"
    end
  end

  def schema_to_typespec(%Schema{type: "string", enum: enum}, _schemas) when not is_nil(enum) do
    # For enums, just use String.t() since Elixir doesn't support literal string types in typespecs
    "String.t()"
  end

  def schema_to_typespec(%Schema{type: "string", format: "date"}, _schemas), do: "Date.t()"

  def schema_to_typespec(%Schema{type: "string", format: "date-time"}, _schemas),
    do: "DateTime.t()"

  def schema_to_typespec(%Schema{type: "string"}, _schemas), do: "String.t()"
  def schema_to_typespec(%Schema{type: "integer"}, _schemas), do: "integer()"
  def schema_to_typespec(%Schema{type: "number"}, _schemas), do: "float()"
  def schema_to_typespec(%Schema{type: "boolean"}, _schemas), do: "boolean()"

  def schema_to_typespec(%Schema{type: "array", items: items}, schemas) do
    item_type = schema_to_typespec(items, schemas)
    "[#{item_type}]"
  end

  def schema_to_typespec(%Schema{type: "object", properties: nil}, _schemas), do: "map()"

  def schema_to_typespec(%Schema{type: "object", properties: properties}, _schemas)
      when not is_nil(properties) do
    # For inline objects, just use map() for now
    # In a more complete implementation, we might generate anonymous structs
    "map()"
  end

  def schema_to_typespec(%Schema{all_of: schemas_list}, schemas) when not is_nil(schemas_list) do
    # For allOf, we'll use the first schema that has properties or is a ref
    # This is a simplification - a full implementation might merge schemas
    schemas_list
    |> Enum.find(fn schema ->
      not is_nil(schema.ref) or not is_nil(schema.properties)
    end)
    |> schema_to_typespec(schemas)
  end

  def schema_to_typespec(%Schema{one_of: _}, _schemas), do: "any()"
  def schema_to_typespec(%Schema{any_of: _}, _schemas), do: "any()"

  def schema_to_typespec(_, _schemas), do: "any()"

  @doc """
  Generates struct fields from a schema's properties.
  Returns a list of field atoms.
  """
  @spec schema_to_struct_fields(Schema.t()) :: [atom()]
  def schema_to_struct_fields(%Schema{properties: nil}), do: []

  def schema_to_struct_fields(%Schema{properties: properties}) do
    properties
    |> Map.keys()
    |> Enum.map(&property_to_field_name/1)
    |> Enum.map(&String.to_atom/1)
  end

  @doc """
  Generates the field type specifications for a struct.
  Returns a list of {field_name, typespec} tuples.
  """
  @spec schema_to_field_types(Schema.t(), map()) :: [{String.t(), String.t()}]
  def schema_to_field_types(%Schema{properties: nil}, _schemas), do: []

  def schema_to_field_types(%Schema{properties: properties, required: required}, schemas) do
    required = required || []

    properties
    |> Enum.map(fn {prop_name, prop_schema} ->
      field_name = property_to_field_name(prop_name)
      base_type = schema_to_typespec(prop_schema, schemas)

      # Add nil to the type if the field is not required
      type =
        if prop_name in required do
          base_type
        else
          "#{base_type} | nil"
        end

      {field_name, type}
    end)
  end

  @doc """
  Generates the from_json function body for converting JSON to struct.
  """
  @spec generate_from_json_body(Schema.t(), String.t()) :: String.t()
  def generate_from_json_body(%Schema{properties: nil}, _module_name), do: "%__MODULE__{}"

  def generate_from_json_body(%Schema{properties: properties}, _module_name) do
    field_mappings =
      properties
      |> Enum.map_join(",\n", fn {prop_name, prop_schema} ->
        field_name = property_to_field_name(prop_name)
        value_expr = generate_value_parser(prop_name, prop_schema)
        "      #{field_name}: #{value_expr}"
      end)

    "    %__MODULE__{\n#{field_mappings}\n    }"
  end

  defp generate_value_parser(prop_name, %Schema{type: "string", format: "date"}) do
    "parse_date(data[\"#{prop_name}\"])"
  end

  defp generate_value_parser(prop_name, %Schema{type: "string", format: "date-time"}) do
    "parse_datetime(data[\"#{prop_name}\"])"
  end

  defp generate_value_parser(prop_name, _schema) do
    "data[\"#{prop_name}\"]"
  end

  @doc """
  Determines if a schema should generate a model.
  Filters out simple types and schemas without properties.
  """
  @spec should_generate_model?(Schema.t()) :: boolean()
  def should_generate_model?(%Schema{type: "object", properties: properties})
      when not is_nil(properties) do
    map_size(properties) > 0
  end

  def should_generate_model?(%Schema{all_of: schemas}) when not is_nil(schemas) do
    # Generate model for allOf if any of the schemas has properties
    Enum.any?(schemas, fn schema ->
      not is_nil(schema.properties) and map_size(schema.properties) > 0
    end)
  end

  def should_generate_model?(_), do: false

  @doc """
  Extracts response schema from an operation's responses.
  Looks for the success response (2xx) and returns its schema if present.
  """
  @spec extract_response_schema(map()) :: String.t() | nil
  def extract_response_schema(responses) when is_map(responses) do
    # Find the first 2xx response with a schema
    responses
    |> Enum.find(fn {status, response} ->
      String.starts_with?(to_string(status), "2") and has_json_schema?(response)
    end)
    |> case do
      {_status, response} -> extract_json_schema_ref(response)
      nil -> nil
    end
  end

  def extract_response_schema(_), do: nil

  defp has_json_schema?(%Portico.Spec.Response{content: content}) do
    has_json_schema?(content)
  end

  defp has_json_schema?(response) when is_map(response) do
    case response["content"] do
      %{"application/json" => %{"schema" => schema}} when is_map(schema) -> true
      _ -> false
    end
  end

  defp has_json_schema?(_), do: false

  defp extract_json_schema_ref(%Portico.Spec.Response{content: content}) do
    extract_json_schema_ref(content)
  end

  defp extract_json_schema_ref(response) when is_map(response) do
    case response["content"] || response do
      %{"application/json" => %{"schema" => %{"$ref" => ref}}} ->
        Schema.resolve_ref_name(ref)

      _ ->
        nil
    end
  end

  defp extract_json_schema_ref(_), do: nil

  @doc """
  Groups operations by their response model type.
  Returns a map where keys are model names and values are lists of {path, operation} tuples.
  """
  @spec group_operations_by_model(list()) :: map()
  def group_operations_by_model(path_operations) do
    path_operations
    |> Enum.reduce(%{}, fn {path, operation}, acc ->
      case extract_response_schema(operation.responses) do
        nil ->
          acc

        model_name ->
          Map.update(acc, model_name, [{path, operation}], &[{path, operation} | &1])
      end
    end)
  end

  @doc """
  Generates field documentation for a schema's properties.
  Returns a list of {field_name, type, description} tuples.
  """
  @spec generate_field_docs(Schema.t()) ::
          list({String.t(), String.t(), String.t() | nil})
  def generate_field_docs(%Schema{properties: properties}) when is_map(properties) do
    properties
    |> Enum.map(fn {prop_name, prop_schema} ->
      field_name = property_to_field_name(prop_name)
      type_str = schema_to_readable_type(prop_schema)
      description = get_schema_description(prop_schema)

      {field_name, type_str, description}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  def generate_field_docs(_), do: []

  defp get_schema_description(%Schema{description: desc}) when is_binary(desc), do: desc
  defp get_schema_description(_), do: nil

  defp schema_to_readable_type(%Schema{ref: ref}) when not is_nil(ref) do
    case Schema.resolve_ref_name(ref) do
      nil -> "object"
      name -> schema_to_module_name(name)
    end
  end

  defp schema_to_readable_type(%Schema{type: "string", format: format}) when not is_nil(format) do
    case format do
      "date-time" -> "datetime"
      "date" -> "date"
      "email" -> "email"
      "uri" -> "uri"
      "uuid" -> "uuid"
      _ -> "string"
    end
  end

  defp schema_to_readable_type(%Schema{type: "string", enum: enum}) when not is_nil(enum) do
    "string (enum)"
  end

  defp schema_to_readable_type(%Schema{type: "array", items: items}) do
    item_type = if items, do: schema_to_readable_type(items), else: "any"
    "[#{item_type}]"
  end

  defp schema_to_readable_type(%Schema{type: "object"}), do: "object"
  defp schema_to_readable_type(%Schema{type: "string"}), do: "string"
  defp schema_to_readable_type(%Schema{type: "integer"}), do: "integer"
  defp schema_to_readable_type(%Schema{type: "number"}), do: "number"
  defp schema_to_readable_type(%Schema{type: "boolean"}), do: "boolean"
  defp schema_to_readable_type(_), do: "any"

  @doc """
  Checks if a schema has any date or datetime fields.
  """
  @spec has_date_fields?(Schema.t()) :: boolean()
  def has_date_fields?(%Schema{properties: properties}) when is_map(properties) do
    Enum.any?(properties, fn {_name, schema} ->
      case schema do
        %Schema{type: "string", format: "date"} -> true
        %Schema{type: "string", format: "date-time"} -> true
        _ -> false
      end
    end)
  end

  def has_date_fields?(_), do: false

  @doc """
  Generates to_json conversion for a field based on its schema.
  """
  @spec generate_to_json_field_mappings(Schema.t()) :: list({String.t(), String.t()})
  def generate_to_json_field_mappings(%Schema{properties: nil}), do: []

  def generate_to_json_field_mappings(%Schema{properties: properties}) do
    properties
    |> Enum.map(fn {prop_name, prop_schema} ->
      field_name = property_to_field_name(prop_name)
      {field_name, prop_name, prop_schema}
    end)
  end
end
