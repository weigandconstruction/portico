defmodule Mix.Tasks.Hydra.Generate do
  @shortdoc "Generate APIs from an OpenAPI spec"
  @moduledoc """
  Generate APIs from an OpenAPI spec.
  """

  use Mix.Task
  import Mix.Generator

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [module: :string, spec: :string]
      )

    opts[:module] || raise "You must provide a name for the API client using --module"
    opts = Keyword.put(opts, :name, Macro.underscore(opts[:module]))

    generate(opts)
  end

  defp generate(opts) do
    spec = Hydra.parse(opts[:spec])

    create_directory("lib/#{opts[:name]}")
    copy_client(opts)
    generate_api_modules(spec, opts)
  end

  defp copy_client(opts) do
    source_path = Path.join(:code.priv_dir(:hydra), "templates/client.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/client.ex", opts, format_elixir: true)
    end
  end

  defp generate_api_modules(spec, opts) do
    for path <- spec.paths do
      generate_api_module(path, opts)
    end
  end

  defp generate_api_module(path, opts) do
    name = Hydra.Helpers.friendly_name(path.path)
    module_name = Hydra.Helpers.module_name(path.path)

    opts =
      opts
      |> Keyword.put(:local_module, module_name)
      |> Keyword.put(:path, path)

    source_path = Path.join(:code.priv_dir(:hydra), "templates/api.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/api/#{name}.ex", opts, format_elixir: true)
    end
  end
end
