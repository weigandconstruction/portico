defmodule Hydra do
  @moduledoc """
  Main entry point for parsing OpenAPI 3.0 specifications.

  Hydra can parse OpenAPI specs from either remote URLs or local files,
  converting them into structured `Hydra.Spec` data that can be used
  for generating API client code.

  ## Examples

      # Parse from a remote URL
      spec = Hydra.parse("https://api.example.com/openapi.json")

      # Parse from a local file
      spec = Hydra.parse("path/to/openapi.json")

  ## Supported Formats

  - Remote HTTPS URLs returning JSON
  - Local JSON files

  ## Error Handling

  The parse functions will raise exceptions on:
  - Invalid JSON format (`Jason.DecodeError`)
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

      # Parse from remote URL
      iex> spec = Hydra.parse("https://api.example.com/openapi.json")
      %Hydra.Spec{openapi: "3.0.0", info: %{...}, paths: %{...}}

      # Parse from local file
      iex> spec = Hydra.parse("./specs/petstore.json")
      %Hydra.Spec{openapi: "3.0.0", info: %{...}, paths: %{...}}

  ## Raises

  - `RuntimeError` if `nil` is passed
  - `Jason.DecodeError` if JSON is malformed
  - `Req` exceptions for network issues
  - `File.Error` if local file doesn't exist

  """
  def parse(nil), do: raise("You must provide a spec URL or file path")

  def parse("https://" <> _ = url) do
    spec = Req.get!(url).body
    Hydra.Spec.parse(spec)
  end

  def parse(file) do
    File.read!(file)
    |> Jason.decode!()
    |> Hydra.Spec.parse()
  end
end
