defmodule Hydra.Fetch do
  @moduledoc """
  Handles fetching OpenAPI specifications from remote URLs.

  Automatically follows redirects and detects content type from
  the final response headers.
  """

  @type content_type :: :json | :yaml | :unknown

  @doc """
  Fetches content from a URL and returns the body with detected content type.

  Returns `{content, content_type}` where content_type is `:json`, `:yaml`, or `:unknown`.
  """
  @spec fetch(String.t()) :: {String.t(), content_type()}
  def fetch(url) do
    response = Req.get!(url, decode_body: false)
    content_type = detect_content_type(response)
    {response.body, content_type}
  end

  defp detect_content_type(response) do
    case Req.Response.get_header(response, "content-type") do
      [content_type | _] ->
        cond do
          String.contains?(content_type, "json") -> :json
          String.contains?(content_type, "yaml") -> :yaml
          String.contains?(content_type, "yml") -> :yaml
          true -> :unknown
        end

      [] ->
        :unknown
    end
  end
end
