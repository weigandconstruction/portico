defmodule Hydra.Spec.Resolver do
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
      
      resolved = Hydra.Spec.Resolver.resolve(spec)
      # resolved["paths"]["/users"]["parameters"] will contain the actual Query parameter

  """
  def resolve(spec) when is_map(spec) do
    resolve_refs(spec, spec, MapSet.new(), %{})
  end

  # Main recursive function that walks the spec tree
  # visiting_refs: MapSet of refs currently being resolved (for cycle detection)
  # resolved_cache: Map of already resolved refs to prevent re-resolution
  defp resolve_refs(current, root, visiting_refs, resolved_cache) when is_map(current) do
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
            # Mark as visiting
            new_visiting = MapSet.put(visiting_refs, ref_path)

            # Resolve the reference
            resolve_json_pointer(ref_path, root)
            |> resolve_refs(root, new_visiting, resolved_cache)
        end

      # Regular map - recursively resolve all values
      true ->
        current
        |> Enum.map(fn {key, value} ->
          {key, resolve_refs(value, root, visiting_refs, resolved_cache)}
        end)
        |> Map.new()
    end
  end

  defp resolve_refs(current, root, visiting_refs, resolved_cache) when is_list(current) do
    Enum.map(current, fn item -> resolve_refs(item, root, visiting_refs, resolved_cache) end)
  end

  defp resolve_refs(current, _root, _visiting_refs, _resolved_cache), do: current

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
end
