defmodule Hydra do
  @moduledoc """
  Main entry point for parsing OpenAPI 3.0 specifications.

  Hydra can parse OpenAPI specs from either remote URLs or local files,
  converting them into structured `Hydra.Spec` data that can be used
  for generating API client code.

  ## Examples

      # Parse from a remote URL
      spec = Hydra.parse!("https://api.example.com/openapi.json")
      spec = Hydra.parse!("https://api.example.com/openapi.yaml")

      # Parse from a local file
      spec = Hydra.parse!("path/to/openapi.json")
      spec = Hydra.parse!("path/to/openapi.yaml")

  ## Supported Formats

  - Remote HTTPS URLs returning JSON or YAML
  - Local JSON files (.json)
  - Local YAML files (.yaml, .yml)

  ## Error Handling

  The parse functions will raise exceptions on:
  - Invalid JSON format (`Jason.DecodeError`)
  - Invalid YAML format (`YamlElixir.ParsingError`)
  - Network errors for remote URLs (`Req` exceptions)
  - File not found for local files (`File.Error`)
  - Invalid OpenAPI structure (validation errors from `Hydra.Spec.parse/1`)

  """

  @doc """
  Parses an OpenAPI specification from a URL or file path.

  ## Parameters

  - `source` - Either an HTTPS URL string or a local file path

  ## Returns

  Returns a `Hydra.Spec` struct containing the parsed OpenAPI specification.

  ## Examples

      # Parse from remote URL (requires network access)
      spec = Hydra.parse!("https://api.example.com/openapi.json")
      spec = Hydra.parse!("https://api.example.com/openapi.yaml")

      # Parse from local file
      spec = Hydra.parse!("./specs/petstore.json")
      spec = Hydra.parse!("./specs/petstore.yaml")

  ## Raises

  - `RuntimeError` if `nil` is passed
  - `Jason.DecodeError` if JSON is malformed
  - `YamlElixir.ParsingError` if YAML is malformed
  - `Req` exceptions for network issues
  - `File.Error` if local file doesn't exist

  """
  def parse!(nil), do: raise("You must provide a spec URL or file path")

  def parse!("https://" <> _ = url) do
    url
    |> Hydra.Fetch.fetch()
    |> do_parse!()
  end

  def parse!(path) do
    {File.read!(path), path_to_content_type(path)}
    |> do_parse!()
  end

  defp do_parse!(content) do
    content
    |> parse_content()
    |> Hydra.Spec.Resolver.resolve()
    |> Hydra.Spec.parse()
  end

  defp path_to_content_type(path) do
    case Path.extname(path) do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      _ -> raise("Unsupported file extension: #{Path.extname(path)}")
    end
  end

  defp parse_content({content, :json}), do: Jason.decode!(content)
  defp parse_content({content, :yaml}), do: YamlElixir.read_from_string!(content)
  defp parse_content(_), do: raise("Unsupported content type or malformed data")
end
