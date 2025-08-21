defmodule Portico.Runtime.ModelHelpers do
  @moduledoc """
  Shared runtime helper functions for Ecto-based models generated from OpenAPI schemas.
  These functions handle JSON conversion, field normalization, and value serialization.
  """

  @doc """
  Normalizes parameters by converting string keys to atoms.
  Only converts to existing atoms for safety.
  """
  def normalize_params(params) when is_map(params) do
    params
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key =
        case k do
          atom when is_atom(atom) ->
            atom

          string when is_binary(string) ->
            try do
              String.to_existing_atom(string)
            rescue
              ArgumentError -> string
            end

          other ->
            other
        end

      if is_atom(key) do
        Map.put(acc, key, v)
      else
        acc
      end
    end)
  end

  @doc """
  Converts a field atom to its JSON key string representation.
  Can be customized per model by passing a custom mapping.
  """
  def field_to_json_key(field, custom_mappings \\ %{}) do
    Map.get(custom_mappings, field, to_string(field))
  end

  @doc """
  Serializes a value for JSON encoding.
  Handles Ecto types, dates, decimals, and nested structs.
  """
  def serialize_value(%Ecto.Association.NotLoaded{}), do: nil
  def serialize_value(%Date{} = date), do: Date.to_iso8601(date)
  def serialize_value(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  def serialize_value(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_iso8601(datetime)
  def serialize_value(%Time{} = time), do: Time.to_iso8601(time)
  def serialize_value(%Decimal{} = decimal), do: Decimal.to_string(decimal)

  def serialize_value(%{__struct__: module} = struct) when is_atom(module) do
    if function_exported?(module, :to_json, 1) do
      module.to_json(struct)
    else
      nil
    end
  end

  def serialize_value(list) when is_list(list) do
    Enum.map(list, &serialize_value/1)
  end

  def serialize_value(value), do: value

  @doc """
  Converts a struct to a JSON-encodable map.
  Removes Ecto metadata and serializes all values appropriately.
  """
  def struct_to_json(struct, custom_field_mappings \\ %{}) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Enum.reduce(%{}, fn {field, value}, acc ->
      json_key = field_to_json_key(field, custom_field_mappings)
      json_value = serialize_value(value)

      if is_nil(json_value) do
        acc
      else
        Map.put(acc, json_key, json_value)
      end
    end)
  end

  @doc """
  Applies a changeset, handling both success and error cases permissively.
  For API responses, we want to be permissive and return data even if validation fails.
  """
  def apply_changeset_permissively(changeset) do
    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, struct} ->
        struct

      {:error, changeset} ->
        # For API responses, we generally want to be permissive
        # Log the error if needed, but return the struct anyway
        Ecto.Changeset.apply_changes(changeset)
    end
  end
end
