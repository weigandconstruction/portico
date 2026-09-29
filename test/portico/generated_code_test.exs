defmodule Portico.GeneratedCodeTest do
  # Generates clients from small specs and compiles the output, so a template
  # change that produces invalid Elixir fails here instead of in a consuming app.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    {:ok, dir} = Briefly.create(type: :directory)
    %{dir: dir}
  end

  defp op(extra \\ %{}) do
    Map.merge(%{"tags" => ["things"], "responses" => %{"200" => %{"description" => "OK"}}}, extra)
  end

  defp param(name, location, extra \\ %{}) do
    Map.merge(%{"name" => name, "in" => location, "schema" => %{"type" => "string"}}, extra)
  end

  # Generates a client for `paths` into `dir`, compiles it, and returns the root module
  defp generate!(dir, paths, info \\ %{"title" => "Test", "version" => "1.0.0"}) do
    root = "Gen#{System.unique_integer([:positive])}"
    spec_file = Path.join(dir, "spec.json")

    File.write!(
      spec_file,
      Jason.encode!(%{"openapi" => "3.0.0", "info" => info, "paths" => paths})
    )

    File.cd!(dir, fn ->
      capture_io(fn ->
        Mix.Tasks.Portico.Generate.run(["--module", root, "--spec", spec_file])
      end)
    end)

    files = Path.wildcard(Path.join(dir, "lib/**/*.ex"))

    # The test environment compiles without docs, but we assert on them
    docs = Code.get_compiler_option(:docs)
    Code.put_compiler_option(:docs, true)
    on_exit(fn -> Code.put_compiler_option(:docs, docs) end)

    {result, output} =
      with_io(:stderr, fn ->
        # compile_to_path only creates the directory itself on Elixir 1.19+
        File.mkdir_p!(Path.join(dir, "ebin"))

        Kernel.ParallelCompiler.compile_to_path(files, Path.join(dir, "ebin"),
          return_diagnostics: true
        )
      end)

    case result do
      {:ok, _modules, %{compile_warnings: []}} ->
        Module.concat([root])

      {:ok, _modules, %{compile_warnings: warnings}} ->
        flunk(
          "generated code compiled with warnings:\n" <>
            Enum.map_join(warnings, "\n", & &1.message)
        )

      {:error, errors, _} ->
        flunk(
          "generated code failed to compile:\n" <>
            Enum.map_join(errors, "\n", & &1.message) <> "\n" <> output
        )
    end
  end

  # The compiled @doc text of a generated function
  defp doc!(dir, module, function) do
    beam = Path.join([dir, "ebin", "#{module}.beam"])
    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(beam)

    Enum.find_value(docs, fn
      {{:function, ^function, _}, _, _, %{"en" => doc}, _} -> doc
      _ -> nil
    end)
  end

  # A client whose adapter echoes back what would have been sent
  defp echo_client(root) do
    adapter = fn request ->
      body = %{
        method: request.method,
        url: URI.to_string(request.url),
        headers: request.headers,
        body: request.body && IO.iodata_to_binary(request.body)
      }

      {request, Req.Response.new(status: 200, body: body)}
    end

    Module.concat(root, Client).new(base_url: "https://api.test", adapter: adapter, retry: false)
  end

  defp call(root, api, function, args) do
    apply(Module.concat(root, api), function, [echo_client(root) | args])
  end

  describe "compiles" do
    test "an operation with no parameters", %{dir: dir} do
      generate!(dir, %{"/things" => %{"get" => op()}})
    end

    test "path, query, and header parameters", %{dir: dir} do
      params = [
        param("thingId", "path", %{"required" => true}),
        param("filter", "query", %{"required" => true}),
        param("limit", "query", %{"schema" => %{"type" => "integer"}}),
        param("X-Request-Id", "header", %{"required" => true}),
        param("X-Trace", "header")
      ]

      generate!(dir, %{"/things/{thingId}" => %{"get" => op(%{"parameters" => params})}})
    end

    test "path-level parameters shared by several operations", %{dir: dir} do
      generate!(dir, %{
        "/things/{id}" => %{
          "parameters" => [param("id", "path", %{"required" => true})],
          "get" => op(),
          "delete" => op()
        }
      })
    end

    test "a JSON request body", %{dir: dir} do
      body = %{
        "content" => %{
          "application/json" => %{
            "schema" => %{
              "type" => "object",
              "required" => ["name"],
              "properties" => %{"name" => %{"type" => "string"}, "size" => %{"type" => "integer"}}
            }
          }
        }
      }

      generate!(dir, %{"/things" => %{"post" => op(%{"requestBody" => body})}})
    end

    test "untagged operations and operations with several tags", %{dir: dir} do
      generate!(dir, %{
        "/untagged" => %{"get" => %{"responses" => %{"200" => %{"description" => "OK"}}}},
        "/multi" => %{"get" => op(%{"tags" => ["one", "two"]})}
      })
    end

    test "a spec without an info version", %{dir: dir} do
      generate!(dir, %{"/things" => %{"get" => op()}}, %{"title" => "Test"})
    end
  end

  describe "spec text" do
    test "is not evaluated or allowed to end a doc early", %{dir: dir} do
      description =
        Enum.join([~S|Ids look like #{prefix}-\d+ (see "docs").|, ~s("""), "Not code"], "\n")

      params = [param("q", "query", %{"description" => ~S(Matches #{name} or """)})]

      root =
        generate!(dir, %{
          "/things" => %{"get" => op(%{"description" => description, "parameters" => params})}
        })

      doc = doc!(dir, Module.concat(root, Things), :get_things)
      assert doc =~ description
      assert doc =~ ~S(Matches #{name} or """)
    end

    test "with quotes in a path is sent as-is", %{dir: dir} do
      params = [param("id", "path", %{"required" => true})]

      root =
        generate!(dir, %{~S(/things/{id}/"raw") => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} = call(root, Things, :get_things_id_raw, ["1"])
      assert sent.url == ~S(https://api.test/things/1/"raw")
    end
  end

  describe "sends" do
    test "path, query, and header parameters where the spec puts them", %{dir: dir} do
      params = [
        param("thingId", "path", %{"required" => true}),
        param("filter", "query", %{"required" => true}),
        param("limit", "query"),
        param("X-Request-Id", "header", %{"required" => true}),
        param("X-Trace", "header")
      ]

      root = generate!(dir, %{"/things/{thingId}" => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} =
        call(root, Things, :get_things_thing_id, ["42", "active", "req-1", [limit: 5]])

      assert sent.method == :get
      assert sent.url == "https://api.test/things/42?filter=active&limit=5"
      assert sent.headers["x-request-id"] == ["req-1"]
      refute Map.has_key?(sent.headers, "x-trace")
    end

    test "a JSON request body", %{dir: dir} do
      body = %{"content" => %{"application/json" => %{"schema" => %{"type" => "object"}}}}
      root = generate!(dir, %{"/things" => %{"post" => op(%{"requestBody" => body})}})

      {:ok, sent} = call(root, Things, :post_things, [%{name: "a"}])

      assert sent.headers["content-type"] == ["application/json"]
      assert Jason.decode!(sent.body) == %{"name" => "a"}
    end
  end
end
