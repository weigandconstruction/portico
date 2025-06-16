defmodule Mix.Tasks.Portico.Config do
  @shortdoc "Generate a configuration file from an OpenAPI spec"
  @moduledoc """
  Generate a configuration file from an OpenAPI spec.

  This task analyzes an OpenAPI specification and generates a JSON configuration
  file that can be used with other Portico tasks. The configuration includes all
  available tags and can be extended in the future to include other options.

  ## Options

    * `--spec` - The URL or file path to the OpenAPI specification (required)
    * `--output` - Path for the output config file (defaults to "portico.config.json")

  ## Examples

      # Generate config file with default name
      mix portico.config --spec https://api.example.com/openapi.json

      # Generate config file with custom name
      mix portico.config --spec spec.json --output my-config.json

  ## Generated Config Format

  The generated configuration file has the following structure:

      {
        "spec_info": {
          "source": "https://api.example.com/openapi.json",
          "title": "My API",
          "module": "ServiceName"
        },
        "tags": ["users", "posts", "comments"]
      }

  This config file can then be used with the generate task:

      mix portico.generate --config my-config.json

  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Start dependencies required for HTTP requests
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [spec: :string, output: :string]
      )

    opts[:spec] || raise "You must provide a spec using --spec"

    output_file = opts[:output] || "portico.config.json"
    generate_config(opts[:spec], output_file)
  end

  defp generate_config(spec_path, output_file) do
    spec = Portico.parse!(spec_path)

    config = %{
      spec_info: extract_spec_info(spec, spec_path),
      tags: extract_unique_tags(spec)
    }

    json_content = Jason.encode!(config, pretty: true)
    File.write!(output_file, json_content)

    Mix.shell().info("Configuration file generated: #{output_file}")
    Mix.shell().info("Found #{length(config.tags)} unique tags")
    Mix.shell().info("Generated module name: #{config.spec_info.module}")
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

  defp extract_spec_info(spec, spec_path) do
    title = get_in(spec.info, ["title"]) || "API"

    %{
      source: spec_path,
      title: title,
      module: generate_module_name(title)
    }
  end

  defp generate_module_name(title) do
    # Convert title to a valid Elixir module name
    name =
      title
      # Remove special characters
      |> String.replace(~r/[^\w\s]/, "")
      # Split on whitespace
      |> String.split(~r/\s+/)
      # Capitalize each word
      |> Enum.map(&String.capitalize/1)
      # Join together
      |> Enum.join()

    name
  end
end
