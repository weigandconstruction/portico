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
    # Group operations by tags
    grouped_operations = Hydra.Helpers.group_operations_by_tag(spec.paths)

    for {tag, path_operations} <- grouped_operations do
      generate_api_module_for_tag(tag, path_operations, opts)
    end
  end

  defp generate_api_module_for_tag(tag, path_operations, opts) do
    # Determine if this is a tag-based module or path-based fallback
    {filename, module_name} =
      if String.starts_with?(tag, "/") do
        # This is a path fallback (no tags were present)
        name = Hydra.Helpers.friendly_name(tag)
        module_name = Hydra.Helpers.module_name(tag)
        {name, module_name}
      else
        # This is a proper tag
        filename = Hydra.Helpers.tag_to_filename(tag)
        module_name = Hydra.Helpers.tag_to_module_name(tag)
        {filename, module_name}
      end

    opts =
      opts
      |> Keyword.put(:local_module, module_name)
      |> Keyword.put(:tag, tag)
      |> Keyword.put(:path_operations, path_operations)

    source_path = Path.join(:code.priv_dir(:hydra), "templates/api.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/api/#{filename}.ex", opts,
        format_elixir: true
      )
    end
  end
end
