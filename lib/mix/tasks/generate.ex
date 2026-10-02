defmodule Mix.Tasks.Portico.Generate do
  @shortdoc "Generate APIs from an OpenAPI spec"
  @moduledoc """
  Generate APIs from an OpenAPI spec.

  ## Options

    * `--config` - Path to a Portico config file (when used, no other options are allowed)
    * `--module` - The name of the API client module (required when not using --config)
    * `--spec` - The URL or file path to the OpenAPI specification (required when not using --config)
    * `--tag` - Generate APIs only for operations with this specific tag
    * `--force` - Overwrite changed files without asking
    * `--quiet` - Don't print each file as it's written

  Files that come out identical are left alone without asking, so `--force`
  only matters for files whose contents changed.

  ## Examples

      # Generate using a config file
      mix portico.generate --config portico.config.json

      # Generate all APIs without config
      mix portico.generate --module MyAPI --spec https://api.example.com/openapi.json

      # Generate APIs only for operations tagged with "users"
      mix portico.generate --module MyAPI --spec spec.json --tag users

      # Regenerate from a config, overwriting changed files without prompts
      mix portico.generate --config portico.config.json --force --quiet

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
        switches: [
          module: :string,
          spec: :string,
          tag: :string,
          config: :string,
          force: :boolean,
          quiet: :boolean
        ]
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
      |> Keyword.put(:base_url, config["base_url"])
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

    # Generation details only go into the client, so regenerating an unchanged
    # spec doesn't touch every API module
    client_opts =
      opts
      |> Keyword.put(:spec_info, spec.info || %{})
      |> Keyword.put(:portico_ref, portico_ref())
      |> Keyword.put(:generated_on, Date.to_iso8601(Date.utc_today()))

    create_directory("lib/#{opts[:name]}", generator_opts(opts))
    copy_client(client_opts)
    generate_api_modules(spec, opts, tag_filters)
  end

  # Commit of the Portico checkout running the task, or the app version when
  # Portico isn't a git dependency (e.g. running inside Portico itself)
  defp portico_ref do
    path = Mix.Project.deps_paths()[:portico]

    with true <- is_binary(path) and File.dir?(Path.join(path, ".git")),
         git when is_binary(git) <- System.find_executable("git"),
         {sha, 0} <- System.cmd(git, ["rev-parse", "--short", "HEAD"], cd: path) do
      String.trim(sha)
    else
      _ -> to_string(Application.spec(:portico, :vsn))
    end
  end

  defp copy_client(opts) do
    source_path = Path.join(:code.priv_dir(:portico), "templates/client.ex.eex")

    if File.exists?(source_path) do
      # Ensure base_url is always present in opts (even if nil)
      opts = Keyword.put_new(opts, :base_url, nil)

      write_template(source_path, "lib/#{opts[:name]}/client.ex", opts)
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

    filtered_operations
    |> Enum.group_by(fn {tag, _} -> module_file(tag) end)
    |> Enum.sort()
    |> Enum.each(fn {{filename, module_name}, tag_groups} ->
      generate_api_module(filename, module_name, tag_groups, opts)
    end)
  end

  # Tags that only differ by case or punctuation map to the same file, so
  # their operations go into one module instead of overwriting each other
  defp generate_api_module(filename, module_name, tag_groups, opts) do
    tags = tag_groups |> Enum.map(&elem(&1, 0)) |> Enum.sort()

    if length(tags) > 1 do
      Mix.shell().info(
        "Merging tags #{Enum.map_join(tags, ", ", &inspect/1)} into #{module_name}"
      )
    end

    path_operations =
      tag_groups
      |> Enum.sort()
      |> Enum.flat_map(&elem(&1, 1))
      |> Enum.uniq_by(fn {path, operation} -> {path.path, operation.method} end)

    opts =
      opts
      |> Keyword.put(:local_module, module_name)
      |> Keyword.put(:tag, Enum.join(tags, ", "))
      |> Keyword.put(:path_operations, path_operations)

    source_path = Path.join(:code.priv_dir(:portico), "templates/api.ex.eex")

    if File.exists?(source_path) do
      write_template(source_path, "lib/#{opts[:name]}/api/#{filename}.ex", opts)
    end
  end

  # {filename, module name} for a tag, or for a path when operations have no tags
  defp module_file("/" <> _ = path) do
    filename =
      case Portico.Helpers.friendly_name(path) do
        "" -> "root"
        name -> name
      end

    {filename, Portico.Helpers.module_name(path)}
  end

  defp module_file(tag) do
    {Portico.Helpers.tag_to_filename(tag), Portico.Helpers.tag_to_module_name(tag)}
  end

  defp generator_opts(opts), do: [force: opts[:force] == true, quiet: opts[:quiet] == true]

  # Formats before handing off to create_file, which compares what it's given
  # against the file on disk. With copy_template's format_elixir option it
  # compared unformatted output, so unchanged files always prompted, and
  # format_elixir doesn't exist before Elixir 1.18.
  #
  # create_file skips that comparison when forced, so only force files whose
  # contents changed; identical files are then left untouched.
  defp write_template(source, target, opts) do
    contents = source |> EEx.eval_file(assigns: opts) |> Code.format_string!()
    contents = IO.iodata_to_binary([contents, ?\n])
    force = opts[:force] == true and File.read(target) != {:ok, contents}
    create_file(target, contents, Keyword.put(generator_opts(opts), :force, force))
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
