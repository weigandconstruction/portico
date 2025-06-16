defmodule Portico.Spec.Resolver do
  @moduledoc """
  Resolves $ref references in OpenAPI specifications.

  This module handles JSON Pointer resolution for $ref objects, replacing them
  with the actual referenced content from within the same document.

  ## Examples

      # Before resolution:
      %{"$ref" => "#/components/parameters/Query"}

      # After resolution (assuming Query parameter exists):
      %{"in" => "query", "name" => "query", "schema" => %{"type" => "string"}}

  """

  @doc """
  Resolves all $ref references in an OpenAPI specification.

  Takes a parsed OpenAPI spec (as a map) and returns the same spec
  with all $ref objects replaced by their referenced content.

  ## Parameters

  - `spec` - The parsed OpenAPI specification as a map

  ## Returns

  The same specification with all $ref references resolved.

  ## Examples

      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/Query"}]
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{"in" => "query", "name" => "q"}
          }
        }
      }

      resolved = Portico.Spec.Resolver.resolve(spec)
      # resolved["paths"]["/users"]["parameters"] will contain the actual Query parameter

  """
  def resolve(spec) when is_map(spec) do
    # Use ETS for caching refs
    cache_table = :ets.new(:portico_cache, [:set, :private])

    try do
      resolve_refs(spec, spec, MapSet.new(), cache_table)
    after
      :ets.delete(cache_table)
    end
  end

  # Main recursive function that walks the spec tree
  # visiting_refs: MapSet of refs currently being resolved (for cycle detection)
  # cache_table: ETS table for mutable cache storage
  defp resolve_refs(current, root, visiting_refs, cache_table) when is_map(current) do
    cond do
      # Handle $ref object - replace with referenced content
      Map.has_key?(current, "$ref") ->
        ref_path = current["$ref"]

        cond do
          # Currently visiting this ref - circular reference, return ref as-is
          MapSet.member?(visiting_refs, ref_path) ->
            current

          # New ref to resolve
          true ->
            case :ets.lookup(cache_table, ref_path) do
              [{_, cached_result}] ->
                cached_result

              [] ->
                # Mark as visiting
                new_visiting = MapSet.put(visiting_refs, ref_path)

                # Resolve the reference
                resolved =
                  resolve_json_pointer(ref_path, root)
                  |> resolve_refs(root, new_visiting, cache_table)

                # Cache more aggressively but avoid huge objects
                # Only skip caching if it's a massive nested structure
                if should_cache?(resolved) do
                  :ets.insert(cache_table, {ref_path, resolved})
                end

                resolved
            end
        end

      # Regular map - recursively resolve all values
      true ->
        # Don't cache regular maps - only cache $ref resolutions
        # This prevents memory explosion from caching huge nested structures
        current
        |> Enum.map(fn {key, value} ->
          {key, resolve_refs(value, root, visiting_refs, cache_table)}
        end)
        |> Map.new()
    end
  end

  defp resolve_refs(current, root, visiting_refs, cache_table) when is_list(current) do
    Enum.map(current, fn item -> resolve_refs(item, root, visiting_refs, cache_table) end)
  end

  defp resolve_refs(current, _root, _visiting_refs, _cache_table), do: current

  # Resolves a JSON Pointer reference like "#/components/parameters/Query"
  defp resolve_json_pointer("#/" <> pointer, root) do
    pointer
    |> String.split("/")
    |> Enum.reduce(root, fn segment, acc ->
      # Handle escaped characters in JSON Pointer
      segment = String.replace(segment, "~1", "/") |> String.replace("~0", "~")

      case acc do
        %{^segment => value} -> value
        _ -> raise "Reference not found: #/#{pointer}"
      end
    end)
  end

  defp resolve_json_pointer(ref, _root) do
    raise "Unsupported reference format: #{ref}. Only internal references starting with '#/' are supported."
  end

  # Check if a resolved value should be cached
  # Cache most things but avoid extremely large nested structures
  defp should_cache?(value) when is_map(value) do
    # Don't cache if it's a huge map (likely a full schema with tons of properties)
    map_size(value) <= 100
  end

  defp should_cache?(value) when is_list(value) do
    # Don't cache very large lists
    length(value) <= 50
  end

  # Primitives and strings are always cached
  defp should_cache?(_value), do: true
end
