defmodule Mix.Tasks.Portico.Generate do
  @shortdoc "Generate APIs from an OpenAPI spec"
  @moduledoc """
  Generate APIs from an OpenAPI spec.

  ## Options

    * `--config` - Path to a Portico config file (when used, no other options are allowed)
    * `--module` - The name of the API client module (required when not using --config)
    * `--spec` - The URL or file path to the OpenAPI specification (required when not using --config)
    * `--tag` - Generate APIs only for operations with this specific tag

  ## Examples

      # Generate using a config file
      mix portico.generate --config portico.config.json

      # Generate all APIs without config
      mix portico.generate --module MyAPI --spec https://api.example.com/openapi.json

      # Generate APIs only for operations tagged with "users"
      mix portico.generate --module MyAPI --spec spec.json --tag users

  ## Config File Format

  When using --config, the file should contain:

      {
        "spec_info": {
          "source": "https://api.example.com/openapi.json",
          "title": "My API",
          "module": "MyAPI"
        },
        "tags": ["users", "posts", "comments"]
      }

  The config file provides the module name and spec source, so --module and --spec
  options are not allowed when using --config.

  """

  use Mix.Task
  import Mix.Generator

  @impl Mix.Task
  def run(args) do
    # Start dependencies required for HTTP requests
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [module: :string, spec: :string, tag: :string, config: :string]
      )

    # Process options based on whether config is provided
    opts = process_options(opts)
    generate(opts)
  end

  defp process_options(opts) do
    if opts[:config] do
      # When using config, validate no other options are provided
      validate_config_usage(opts)

      # Load config and extract module/spec info
      config = load_full_config(opts[:config])

      opts
      |> Keyword.put(:module, config["spec_info"]["module"])
      |> Keyword.put(:spec, config["spec_info"]["source"])
      |> Keyword.put(:name, Macro.underscore(config["spec_info"]["module"]))
      |> Keyword.put(:tags, config["tags"])
    else
      # Traditional usage - require module and spec
      opts[:module] || raise "You must provide a name for the API client using --module"
      opts[:spec] || raise "You must provide a spec using --spec"

      Keyword.put(opts, :name, Macro.underscore(opts[:module]))
    end
  end

  defp validate_config_usage(opts) do
    invalid_opts = []

    invalid_opts = if opts[:module], do: ["--module" | invalid_opts], else: invalid_opts
    invalid_opts = if opts[:spec], do: ["--spec" | invalid_opts], else: invalid_opts
    invalid_opts = if opts[:tag], do: ["--tag" | invalid_opts], else: invalid_opts

    unless Enum.empty?(invalid_opts) do
      raise "When using --config, the following options are not allowed: #{Enum.join(invalid_opts, ", ")}"
    end
  end

  defp generate(opts) do
    spec = Portico.parse!(opts[:spec])

    # Parse tag filters from CLI options or config file
    tag_filters = parse_tag_filters(opts)

    create_directory("lib/#{opts[:name]}")
    copy_client(opts)
    generate_api_modules(spec, opts, tag_filters)
  end

  defp copy_client(opts) do
    source_path = Path.join(:code.priv_dir(:portico), "templates/client.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/client.ex", opts, format_elixir: true)
    end
  end

  defp generate_api_modules(spec, opts, tag_filters) do
    # Group operations by tags
    grouped_operations = Portico.Helpers.group_operations_by_tag(spec.paths)

    # Filter operations by tags if filters are provided
    filtered_operations =
      if tag_filters do
        filter_operations_by_tags(grouped_operations, tag_filters)
      else
        grouped_operations
      end

    for {tag, path_operations} <- filtered_operations do
      generate_api_module_for_tag(tag, path_operations, opts)
    end
  end

  defp generate_api_module_for_tag(tag, path_operations, opts) do
    # Determine if this is a tag-based module or path-based fallback
    {filename, module_name} =
      if String.starts_with?(tag, "/") do
        # This is a path fallback (no tags were present)
        name = Portico.Helpers.friendly_name(tag)
        module_name = Portico.Helpers.module_name(tag)
        {name, module_name}
      else
        # This is a proper tag
        filename = Portico.Helpers.tag_to_filename(tag)
        module_name = Portico.Helpers.tag_to_module_name(tag)
        {filename, module_name}
      end

    opts =
      opts
      |> Keyword.put(:local_module, module_name)
      |> Keyword.put(:tag, tag)
      |> Keyword.put(:path_operations, path_operations)

    source_path = Path.join(:code.priv_dir(:portico), "templates/api.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/api/#{filename}.ex", opts,
        format_elixir: true
      )
    end
  end

  defp parse_tag_filters(opts) do
    cond do
      # Single tag from CLI
      opts[:tag] ->
        [opts[:tag]]

      # Tags from processed config
      opts[:tags] ->
        opts[:tags]

      # No filters
      true ->
        nil
    end
  end

  defp load_full_config(config_path) do
    case File.read(config_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, config} ->
            validate_config_structure(config)
            config

          {:error, reason} ->
            raise "Failed to parse config file as JSON: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to read config file: #{inspect(reason)}"
    end
  end

  defp validate_config_structure(config) do
    unless Map.has_key?(config, "spec_info") do
      raise "Config file must contain a 'spec_info' field"
    end

    spec_info = config["spec_info"]

    unless is_map(spec_info) and Map.has_key?(spec_info, "source") and
             Map.has_key?(spec_info, "module") do
      raise "Config 'spec_info' must contain 'source' and 'module' fields"
    end

    unless Map.has_key?(config, "tags") and is_list(config["tags"]) do
      raise "Config file must contain a 'tags' field with a list of tag names"
    end
  end

  defp filter_operations_by_tags(grouped_operations, tag_filters) do
    Enum.filter(grouped_operations, fn {tag, _path_operations} ->
      # Include if tag is in the filter list, or if it's a path fallback and no matching tags exist
      tag in tag_filters or
        (String.starts_with?(tag, "/") and
           no_matching_tags_exist?(grouped_operations, tag_filters))
    end)
  end

  defp no_matching_tags_exist?(grouped_operations, tag_filters) do
    tag_keys = Map.keys(grouped_operations) |> Enum.reject(&String.starts_with?(&1, "/"))
    Enum.empty?(Enum.filter(tag_keys, &(&1 in tag_filters)))
  end
end
