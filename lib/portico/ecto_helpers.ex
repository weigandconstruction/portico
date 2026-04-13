defmodule Portico.EctoHelpers do
  @moduledoc """
  Helper functions for generating Ecto embedded schema models from OpenAPI schemas.
  """

  alias Portico.Spec.Schema
  alias Portico.ModelHelpers

  @doc """
  Converts an OpenAPI schema type to an Ecto field type.
  """
  @spec schema_to_ecto_type(Schema.t() | nil) :: atom() | {:array, atom()} | nil
  def schema_to_ecto_type(nil), do: :string

  def schema_to_ecto_type(%Schema{type: "string", format: format}) do
    case format do
      "date" -> :date
      "date-time" -> :utc_datetime
      "time" -> :time
      "email" -> :string
      "uri" -> :string
      "uuid" -> Ecto.UUID
      "binary" -> :binary
      _ -> :string
    end
  end

  def schema_to_ecto_type(%Schema{type: "integer"}), do: :integer
  def schema_to_ecto_type(%Schema{type: "number", format: "float"}), do: :float
  def schema_to_ecto_type(%Schema{type: "number"}), do: :decimal
  def schema_to_ecto_type(%Schema{type: "boolean"}), do: :boolean

  def schema_to_ecto_type(%Schema{type: "array", items: items}) do
    case schema_to_ecto_type(items) do
      nil -> {:array, :map}
      type -> {:array, type}
    end
  end

  # For object types without properties, we'll use :map
  def schema_to_ecto_type(%Schema{type: "object"}), do: :map

  # For refs, we'll handle them as embeds in a different function
  def schema_to_ecto_type(%Schema{ref: ref}) when not is_nil(ref), do: nil

  def schema_to_ecto_type(_), do: :map

  @doc """
  Extracts fields that should be Ecto fields (not embedded schemas).
  Returns a list of {field_name, ecto_type, json_name} tuples.
  """
  @spec extract_ecto_fields(Schema.t()) :: [{atom(), atom() | {:array, atom()}, String.t()}]
  def extract_ecto_fields(%Schema{properties: nil}), do: []

  def extract_ecto_fields(%Schema{properties: properties}) do
    properties
    |> Enum.filter(fn {_name, schema} ->
      # Include if it's not a ref or complex object
      not is_embedded_field?(schema)
    end)
    |> Enum.map(fn {prop_name, prop_schema} ->
      field_name = ModelHelpers.property_to_field_name(prop_name)
      ecto_type = schema_to_ecto_type(prop_schema)
      {String.to_atom(field_name), ecto_type, prop_name}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  Extracts fields that should be embedded schemas.
  Returns a list of {field_name, module_name, cardinality} tuples.
  cardinality is either :embeds_one or :embeds_many
  Only includes fields with actual $ref references to defined models.
  """
  @spec extract_embedded_fields(Schema.t(), String.t()) :: [{atom(), String.t(), atom()}]
  def extract_embedded_fields(%Schema{properties: nil}, _base_module), do: []

  def extract_embedded_fields(%Schema{properties: properties}, base_module) do
    properties
    |> Enum.filter(fn {_name, schema} ->
      is_embedded_field?(schema)
    end)
    |> Enum.map(fn {prop_name, prop_schema} ->
      field_name = ModelHelpers.property_to_field_name(prop_name)
      {module_name, cardinality} = embedded_module_info(prop_schema, base_module)
      {String.to_atom(field_name), module_name, cardinality}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  # Only treat fields with actual $ref references as embedded
  defp is_embedded_field?(%Schema{ref: ref}) when not is_nil(ref), do: true

  defp is_embedded_field?(%Schema{type: "array", items: %Schema{ref: ref}})
       when not is_nil(ref),
       do: true

  defp is_embedded_field?(_), do: false

  defp embedded_module_info(%Schema{ref: ref}, base_module) when not is_nil(ref) do
    case Schema.resolve_ref_name(ref) do
      nil ->
        {base_module <> ".UnknownModel", :embeds_one}

      name ->
        module_name = ModelHelpers.schema_to_module_name(name)
        {base_module <> ".Models." <> module_name, :embeds_one}
    end
  end

  defp embedded_module_info(%Schema{type: "array", items: %Schema{ref: ref}}, base_module)
       when not is_nil(ref) do
    case Schema.resolve_ref_name(ref) do
      nil ->
        {base_module <> ".UnknownModel", :embeds_many}

      name ->
        module_name = ModelHelpers.schema_to_module_name(name)
        {base_module <> ".Models." <> module_name, :embeds_many}
    end
  end

  defp embedded_module_info(%Schema{type: "object"}, base_module) do
    # For inline objects, we might want to generate inline embedded schemas
    # For now, treat as a map field instead
    {base_module <> ".InlineModel", :embeds_one}
  end

  defp embedded_module_info(%Schema{type: "array"}, base_module) do
    {base_module <> ".InlineModel", :embeds_many}
  end

  defp embedded_module_info(_, base_module) do
    {base_module <> ".UnknownModel", :embeds_one}
  end

  @doc """
  Generates field mappings between JSON keys and Elixir field names.
  Only includes mappings where they differ.
  """
  @spec generate_field_mappings(Schema.t()) :: [{String.t(), atom()}]
  def generate_field_mappings(%Schema{properties: nil}), do: []

  def generate_field_mappings(%Schema{properties: properties}) do
    properties
    |> Map.keys()
    |> Enum.map(fn prop_name ->
      field_name = ModelHelpers.property_to_field_name(prop_name)

      if field_name != prop_name do
        {prop_name, String.to_atom(field_name)}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
