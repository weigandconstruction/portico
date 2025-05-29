defmodule Hydra.Spec.Response do
  @moduledoc """
  Represents a response in the OpenAPI 3.0 specification.

  A response is the data returned by an API endpoint after processing a request.
  It includes details such as the description, headers, content, and links.
  Each response can have multiple content types, headers, and links associated with it.
  """

  @type t() :: %__MODULE__{
          description: String.t() | nil,
          headers: map(),
          content: map(),
          links: map()
        }

  defstruct [
    :description,
    headers: %{},
    content: %{},
    links: %{}
  ]

  @doc """
  Parses a response from the OpenAPI 3.0 specification.
  This function takes a map containing the response details and returns a `Hydra.Spec.Response` struct.
  """
  @spec parse(map()) :: t()
  def parse(response) do
    %__MODULE__{
      description: response["description"],
      headers: response["headers"] || %{},
      content: response["content"] || %{},
      links: response["links"] || %{}
    }
  end
end
