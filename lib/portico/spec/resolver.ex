defmodule Portico.Spec.Resolver do
  @moduledoc """
  Resolves $ref references in OpenAPI specifications.

  This module handles JSON Pointer resolution for $ref objects, replacing them
  with the actual referenced content from within the same document.

  ## Schema references

  References that target `#/components/schemas/...` are special: they are
  resolved like any other reference (their content is inlined), but the
  original `$ref` pointer is **preserved** as a key on the resulting map.
  This lets downstream tooling treat component schemas as named types (e.g.
  to generate an `embeds_one :user, MyAPI.Models.User` rather than
  re-inlining User's fields as an anonymous map) while still giving it
  access to the resolved shape for inline use (typespecs, docs, validation).

  Non-schema references (parameters, requestBodies, responses, headers,
  etc.) are resolved without any metadata — they become the raw referenced
  value.

  ## Examples

      # Parameter ref — fully inlined, no $ref survives:
      %{"$ref" => "#/components/parameters/Query"}
      # → %{"in" => "query", "name" => "q", "schema" => %{"type" => "string"}}

      # Schema ref — inlined *and* tagged with its original pointer:
      %{"$ref" => "#/components/schemas/User"}
      # → %{
      #     "$ref" => "#/components/schemas/User",
      #     "type" => "object",
      #     "properties" => %{...}
      #   }
  """

  @schema_ref_prefix "#/components/schemas/"

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
        preserve? = schema_ref?(ref_path)

        cond do
          # Currently visiting this ref - circular reference, return ref-only map.
          # For schema refs, that's already the desired "ref-as-handle" shape;
          # for other refs, there is nothing else we can do without looping.
          MapSet.member?(visiting_refs, ref_path) ->
            %{"$ref" => ref_path}

          true ->
            case :ets.lookup(cache_table, ref_path) do
              [{_, cached_result}] ->
                cached_result

              [] ->
                # Mark as visiting
                new_visiting = MapSet.put(visiting_refs, ref_path)

                # Resolve and recurse into the referenced value
                resolved =
                  ref_path
                  |> resolve_json_pointer(root)
                  |> resolve_refs(root, new_visiting, cache_table)

                # For schema refs, preserve the original pointer as metadata
                # so downstream code can still identify the named type.
                tagged =
                  if preserve? and is_map(resolved) do
                    Map.put(resolved, "$ref", ref_path)
                  else
                    resolved
                  end

                # Cache more aggressively but avoid huge objects
                if should_cache?(tagged) do
                  :ets.insert(cache_table, {ref_path, tagged})
                end

                tagged
            end
        end

      # Regular map - recursively resolve all values
      true ->
        # Don't cache regular maps - only cache $ref resolutions
        # This prevents memory explosion from caching huge nested structures
        Map.new(current, fn {key, value} ->
          {key, resolve_refs(value, root, visiting_refs, cache_table)}
        end)
    end
  end

  defp resolve_refs(current, root, visiting_refs, cache_table) when is_list(current) do
    Enum.map(current, fn item -> resolve_refs(item, root, visiting_refs, cache_table) end)
  end

  defp resolve_refs(current, _root, _visiting_refs, _cache_table), do: current

  # Does this ref point at a named component schema?
  defp schema_ref?(ref) when is_binary(ref), do: String.starts_with?(ref, @schema_ref_prefix)
  defp schema_ref?(_), do: false

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
