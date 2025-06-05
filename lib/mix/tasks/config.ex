defmodule Mix.Tasks.Hydra.Config do
  @shortdoc "Generate a configuration file from an OpenAPI spec"
  @moduledoc """
  Generate a configuration file from an OpenAPI spec.

  This task analyzes an OpenAPI specification and generates a JSON configuration
  file that can be used with other Hydra tasks. The configuration includes all
  available tags and can be extended in the future to include other options.

  ## Options

    * `--spec` - The URL or file path to the OpenAPI specification (required)
    * `--output` - Path for the output config file (defaults to "hydra.config.json")

  ## Examples

      # Generate config file with default name
      mix hydra.config --spec https://api.example.com/openapi.json

      # Generate config file with custom name
      mix hydra.config --spec spec.json --output my-config.json

  ## Generated Config Format

  The generated configuration file has the following structure:

      {
        "tags": ["users", "posts", "comments"],
        "spec_info": {
          "title": "My API",
          "version": "1.0.0"
        }
      }

  This config file can then be used with the generate task:

      mix hydra.generate --module MyAPI --spec spec.json --config my-config.json

  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [spec: :string, output: :string]
      )

    opts[:spec] || raise "You must provide a spec using --spec"

    output_file = opts[:output] || "hydra.config.json"
    generate_config(opts[:spec], output_file)
  end

  defp generate_config(spec_path, output_file) do
    spec = Hydra.parse!(spec_path)

    config = %{
      tags: extract_unique_tags(spec),
      spec_info: extract_spec_info(spec)
    }

    json_content = Jason.encode!(config, pretty: true)
    File.write!(output_file, json_content)

    Mix.shell().info("Configuration file generated: #{output_file}")
    Mix.shell().info("Found #{length(config.tags)} unique tags")
  end

  defp extract_unique_tags(spec) do
    spec.paths
    |> Enum.flat_map(fn path ->
      Enum.flat_map(path.operations, fn operation ->
        operation.tags
      end)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract_spec_info(spec) do
    %{
      title: get_in(spec.info, ["title"]),
      version: get_in(spec.info, ["version"]),
      description: get_in(spec.info, ["description"])
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
