defmodule Mix.Tasks.Hydra.Generate do
  @shortdoc "Generate APIs from an OpenAPI spec"
  @moduledoc """
  Generate APIs from an OpenAPI spec.

  ## Options

    * `--module` - The name of the API client module (required)
    * `--spec` - The URL or file path to the OpenAPI specification (required)
    * `--tag` - Generate APIs only for operations with this specific tag
    * `--config` - Path to a JSON config file containing a list of tags to generate

  ## Examples

      # Generate all APIs
      mix hydra.generate --module MyAPI --spec https://api.example.com/openapi.json

      # Generate APIs only for operations tagged with "users"
      mix hydra.generate --module MyAPI --spec spec.json --tag users

      # Generate APIs for multiple tags using a config file
      mix hydra.generate --module MyAPI --spec spec.json --config tags.json

  ## Config File Format

  The config file should be a JSON file with the following format:

      {
        "tags": ["users", "posts", "comments"]
      }

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

    opts[:module] || raise "You must provide a name for the API client using --module"
    opts = Keyword.put(opts, :name, Macro.underscore(opts[:module]))

    generate(opts)
  end

  defp generate(opts) do
    spec = Hydra.parse!(opts[:spec])

    # Parse tag filters from CLI options or config file
    tag_filters = parse_tag_filters(opts)

    create_directory("lib/#{opts[:name]}")
    copy_client(opts)
    generate_api_modules(spec, opts, tag_filters)
  end

  defp copy_client(opts) do
    source_path = Path.join(:code.priv_dir(:hydra), "templates/client.ex.eex")

    if File.exists?(source_path) do
      copy_template(source_path, "lib/#{opts[:name]}/client.ex", opts, format_elixir: true)
    end
  end

  defp generate_api_modules(spec, opts, tag_filters) do
    # Group operations by tags
    grouped_operations = Hydra.Helpers.group_operations_by_tag(spec.paths)

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

  defp parse_tag_filters(opts) do
    cond do
      # Single tag from CLI
      opts[:tag] ->
        [opts[:tag]]

      # Config file with tags
      opts[:config] ->
        load_config_file(opts[:config])

      # No filters
      true ->
        nil
    end
  end

  defp load_config_file(config_path) do
    case File.read(config_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"tags" => tags}} when is_list(tags) ->
            tags

          {:ok, _} ->
            raise "Config file must contain a 'tags' field with a list of tag names"

          {:error, reason} ->
            raise "Failed to parse config file as JSON: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to read config file: #{inspect(reason)}"
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
