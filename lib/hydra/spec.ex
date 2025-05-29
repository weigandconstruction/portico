defmodule Hydra.Spec do
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

  def parse(json) do
    %__MODULE__{
      version: json["openapi"],
      info: json["info"],
      paths: Enum.map(json["paths"], &Hydra.Path.parse/1),
      servers: json["servers"],
      components: json["components"],
      security: json["security"],
      tags: json["tags"],
      external_docs: json["externalDocs"]
    }
  end

  # defp parse_paths(paths) do
  #   Enum.map(paths, fn path ->
  #     Hydra.Path.parse(path)
  #   end)
  # end

  def filter_paths(%__MODULE__{} = spec, path_regex) do
    paths =
      Map.filter(spec.paths, fn {path, _} ->
        Regex.match?(path_regex, path)
      end)

    %{spec | paths: paths}
  end

  def generate_path do
  end
end
