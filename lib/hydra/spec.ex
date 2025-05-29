defmodule Hydra.Spec do
  @moduledoc """
  Represents the OpenAPI 3.0 specification for an API.
  The Hydra.Spec module provides a structure to hold the OpenAPI specification,
  including metadata about the API, paths, servers, components, security schemes, tags, and external documentation.
  It also includes functions to parse the OpenAPI JSON into a structured format.
  """

  @type t() :: %__MODULE__{
          version: String.t(),
          info: map(),
          paths: [Hydra.Spec.Path.t()],
          servers: list(),
          components: map(),
          security: list(),
          tags: list(),
          external_docs: map()
        }

  defstruct [
    :version,
    info: %{},
    paths: [],
    servers: [],
    components: [],
    security: [],
    tags: [],
    external_docs: %{}
  ]

  @doc """
  Parses the OpenAPI 3.0 specification from a JSON object.
  This function takes a JSON object representing the OpenAPI specification and returns a `Hydra.Spec` struct.
  """
  @spec parse(map()) :: t()
  def parse(json) do
    %__MODULE__{
      version: json["openapi"],
      info: json["info"],
      paths: Enum.map(json["paths"], &Hydra.Spec.Path.parse/1),
      servers: json["servers"],
      components: json["components"],
      security: json["security"],
      tags: json["tags"],
      external_docs: json["externalDocs"]
    }
  end
end
