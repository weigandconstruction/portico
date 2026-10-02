defmodule Portico do
  @moduledoc """
  Main entry point for parsing OpenAPI 3.0 specifications.

  Portico can parse OpenAPI specs from either remote URLs or local files,
  converting them into structured `Portico.Spec` data that can be used
  for generating API client code.

  ## Examples

      # Parse from a remote URL
      spec = Portico.parse!("https://api.example.com/openapi.json")
      spec = Portico.parse!("https://api.example.com/openapi.yaml")

      # Parse from a local file
      spec = Portico.parse!("path/to/openapi.json")
      spec = Portico.parse!("path/to/openapi.yaml")

  ## Supported Formats

  - Remote HTTP(S) URLs returning JSON or YAML
  - Local JSON files (.json)
  - Local YAML files (.yaml, .yml)

  ## Error Handling

  The parse functions will raise exceptions on:
  - Invalid JSON format (`Jason.DecodeError`)
  - Invalid YAML format (`YamlElixir.ParsingError`)
  - Network errors for remote URLs (`Req` exceptions)
  - File not found for local files (`File.Error`)
  - Invalid OpenAPI structure (validation errors from `Portico.Spec.parse/1`)

  """

  @doc """
  Parses an OpenAPI specification from a URL or file path.

  ## Parameters

  - `source` - Either an HTTP(S) URL string or a local file path

  ## Returns

  Returns a `Portico.Spec` struct containing the parsed OpenAPI specification.

  ## Examples

      # Parse from remote URL (requires network access)
      spec = Portico.parse!("https://api.example.com/openapi.json")
      spec = Portico.parse!("https://api.example.com/openapi.yaml")

      # Parse from local file
      spec = Portico.parse!("./specs/petstore.json")
      spec = Portico.parse!("./specs/petstore.yaml")

  ## Raises

  - `RuntimeError` if `nil` is passed
  - `Jason.DecodeError` if JSON is malformed
  - `YamlElixir.ParsingError` if YAML is malformed
  - `Req` exceptions for network issues
  - `RuntimeError` if a URL doesn't return a 2xx status
  - `File.Error` if local file doesn't exist
  - `RuntimeError` if the content isn't an OpenAPI 3 spec

  """
  def parse!(nil), do: raise("You must provide a spec URL or file path")

  def parse!("https://" <> _ = url), do: url |> Portico.Fetch.fetch() |> do_parse!()
  def parse!("http://" <> _ = url), do: url |> Portico.Fetch.fetch() |> do_parse!()

  def parse!(path) do
    {File.read!(path), path_to_content_type(path)}
    |> do_parse!()
  end

  defp do_parse!(content) do
    content
    |> parse_content()
    |> validate_openapi!()
    |> Portico.Spec.Resolver.resolve()
    |> Portico.Spec.parse()
  end

  defp path_to_content_type(path) do
    case Path.extname(path) do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      _ -> raise("Unsupported file extension: #{Path.extname(path)}")
    end
  end

  # Plain text like "404: Not Found" is valid YAML, so check the shape before
  # resolving refs rather than failing somewhere confusing later
  defp validate_openapi!(%{"openapi" => "3." <> _, "paths" => paths} = spec) when is_map(paths),
    do: spec

  defp validate_openapi!(%{"swagger" => version}) do
    raise "Swagger #{version} specs aren't supported. Convert the spec to OpenAPI 3 first."
  end

  defp validate_openapi!(%{"openapi" => "3." <> _}) do
    raise "The spec has no paths"
  end

  defp validate_openapi!(%{"openapi" => version}) do
    raise "Only OpenAPI 3 specs are supported, got version #{inspect(version)}"
  end

  defp validate_openapi!(content) do
    raise "This doesn't look like an OpenAPI spec (no \"openapi\" field). It starts with: " <>
            (content |> inspect() |> String.slice(0, 80))
  end

  defp parse_content({content, :json}), do: Jason.decode!(content)
  defp parse_content({content, :yaml}), do: YamlElixir.read_from_string!(content)
  defp parse_content(_), do: raise("Unsupported content type or malformed data")
end
