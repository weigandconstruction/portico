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
  # Options: :info for the spec's info map, :base_url to generate through a
  # config with a default base URL
  defp generate!(dir, paths, opts \\ []) do
    root = "Gen#{System.unique_integer([:positive])}"
    File.mkdir_p!(dir)
    spec_file = Path.join(dir, "spec.json")
    info = Keyword.get(opts, :info, %{"title" => "Test", "version" => "1.0.0"})

    File.write!(
      spec_file,
      Jason.encode!(%{"openapi" => "3.0.0", "info" => info, "paths" => paths})
    )

    args =
      if base_url = opts[:base_url] do
        config_file = Path.join(dir, "config.json")

        tags =
          paths |> Map.values() |> Enum.flat_map(&Map.values/1) |> Enum.flat_map(& &1["tags"])

        File.write!(
          config_file,
          Jason.encode!(%{
            "spec_info" => %{"source" => spec_file, "module" => root},
            "base_url" => base_url,
            "tags" => Enum.uniq(tags)
          })
        )

        ["--config", config_file]
      else
        ["--module", root, "--spec", spec_file]
      end

    File.cd!(dir, fn ->
      capture_io(fn -> Mix.Tasks.Portico.Generate.run(args) end)
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

  defp body_paths(content_types) do
    content = Map.new(content_types, &{&1, %{"schema" => %{"type" => "object"}}})
    %{"/things" => %{"post" => op(%{"requestBody" => %{"content" => content}})}}
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

    test "a path parameter the spec forgot to mark required", %{dir: dir} do
      params = [param("id", "path")]
      root = generate!(dir, %{"/things/{id}" => %{"get" => op(%{"parameters" => params})}})

      assert {:ok, %{url: "https://api.test/things/7"}} =
               call(root, Things, :get_things_id, ["7"])
    end

    test "a spec without an info version", %{dir: dir} do
      generate!(dir, %{"/things" => %{"get" => op()}}, info: %{"title" => "Test"})
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

    test "in parameter names that aren't identifiers is sent under the original name", %{
      dir: dir
    } do
      params = [
        param("page size", "query", %{"required" => true}),
        param("filter:name", "query"),
        param("sort+", "query"),
        param("2fa", "query"),
        param(~S(X-"Quoted"), "header", %{"required" => true})
      ]

      root = generate!(dir, %{"/things" => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} =
        call(root, Things, :get_things, ["10", "v", [filter_name: "a", sort_: "b", n2fa: "c"]])

      assert URI.decode_query(URI.parse(sent.url).query) == %{
               "page size" => "10",
               "filter:name" => "a",
               "sort+" => "b",
               "2fa" => "c"
             }

      assert sent.headers[~S(x-"quoted")] == ["v"]
    end

    test "in parameter names ending in ? or ! keeps them apart from ones ending in _", %{
      dir: dir
    } do
      params = [
        param("enabled?", "query", %{"required" => true}),
        param("enabled_", "query", %{"required" => true}),
        param("force!", "query"),
        param("force_", "query")
      ]

      root = generate!(dir, %{"/things" => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} = call(root, Things, :get_things, ["yes", "no", [force!: "a", force_: "b"]])

      assert URI.decode_query(URI.parse(sent.url).query) == %{
               "enabled?" => "yes",
               "enabled_" => "no",
               "force!" => "a",
               "force_" => "b"
             }
    end

    test "in paths that aren't identifiers still gives valid function and module names", %{
      dir: dir
    } do
      root =
        generate!(dir, %{
          "/a+b" => %{"get" => op()},
          ~S(/c#{d}\e) => %{"get" => op()},
          "/" => %{"get" => %{"responses" => %{"200" => %{"description" => "OK"}}}},
          "/2fa/setup" => %{"get" => %{"responses" => %{"200" => %{"description" => "OK"}}}}
        })

      assert {:ok, %{url: "https://api.test/a+b"}} = call(root, Things, :get_a_b, [])
      assert {:ok, %{url: "https://api.test/"}} = call(root, Root, :get_, [])
      assert {:ok, _} = call(root, N2faSetup, :get_2fa_setup, [])
      assert Module.concat(root, Things).__info__(:functions)[:get_c_d_e] == 1
    end

    test "in paths that only differ by - and _ gives each its own function", %{dir: dir} do
      root =
        generate!(dir, %{
          "/time_off/requests" => %{"get" => op(%{"parameters" => [param("page", "query")]})},
          "/time-off/requests" => %{"get" => op(%{"parameters" => [param("page", "query")]})}
        })

      assert {:ok, %{url: "https://api.test/time_off/requests"}} =
               call(root, Things, :get_time_off_requests, [])

      assert {:ok, %{url: "https://api.test/time-off/requests"}} =
               call(root, Things, :get_time_off_requests_2, [])
    end

    test "in a path whose name looks like a suffix keeps it from a colliding path", %{dir: dir} do
      required = [param("page", "query", %{"required" => true})]

      root =
        generate!(dir, %{
          "/time_off" => %{"get" => op()},
          "/time-off" => %{"get" => op(%{"parameters" => required})},
          "/time_off_2" => %{"get" => op(%{"parameters" => required})}
        })

      functions = Module.concat(root, Things).__info__(:functions)
      assert functions[:get_time_off] == 1
      assert functions[:get_time_off_2] == 2
      assert functions[:get_time_off_3] == 2

      assert {:ok, %{url: "https://api.test/time_off"}} = call(root, Things, :get_time_off, [])

      assert {:ok, %{url: "https://api.test/time_off_2?page=1"}} =
               call(root, Things, :get_time_off_2, ["1"])

      assert {:ok, %{url: "https://api.test/time-off?page=1"}} =
               call(root, Things, :get_time_off_3, ["1"])
    end

    test "in tags that map to the same file puts both in one module", %{dir: dir} do
      root =
        generate!(dir, %{
          "/a" => %{"get" => op(%{"tags" => ["user-management"]})},
          "/b" => %{"get" => op(%{"tags" => ["User Management"]})},
          "/c" => %{"get" => op(%{"tags" => ["user-management", "User Management"]})},
          "/users" => %{"get" => %{"responses" => %{"200" => %{"description" => "OK"}}}},
          "/d" => %{"get" => op(%{"tags" => ["users"]})}
        })

      functions = Module.concat(root, UserManagement).__info__(:functions)
      assert Enum.sort(Keyword.keys(functions)) == [:get_a, :get_b, :get_c]

      functions = Module.concat(root, Users).__info__(:functions)
      assert Enum.sort(Keyword.keys(functions)) == [:get_d, :get_users]
    end

    test "with quotes in a path is sent as-is", %{dir: dir} do
      params = [param("id", "path", %{"required" => true})]

      root =
        generate!(dir, %{~S(/things/{id}/"raw") => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} = call(root, Things, :get_things_id_raw, ["1"])
      assert sent.url == ~S(https://api.test/things/1/"raw")
    end
  end

  describe "returns" do
    setup %{dir: dir} do
      %{root: generate!(dir, %{"/things" => %{"get" => op()}})}
    end

    defp respond(root, status, client_opts) do
      adapter = fn request ->
        response = Req.Response.new(status: status, body: %{"ok" => true})
        {request, Req.Response.put_header(response, "x-total", "42")}
      end

      opts = [base_url: "https://api.test", adapter: adapter, retry: false] ++ client_opts
      Module.concat(root, Things).get_things(Module.concat(root, Client).new(opts))
    end

    test "the body by default", %{root: root} do
      assert respond(root, 200, []) == {:ok, %{"ok" => true}}
    end

    test "the whole response with return: :response", %{root: root} do
      assert {:ok, %Req.Response{status: 200, body: %{"ok" => true}} = response} =
               respond(root, 200, return: :response)

      assert Req.Response.get_header(response, "x-total") == ["42"]
    end

    test "headers on an HTTPError either way", %{root: root} do
      for opts <- [[], [return: :response]] do
        assert {:error, %{status: 429, body: %{"ok" => true}, headers: headers}} =
                 respond(root, 429, opts)

        assert headers["x-total"] == ["42"]
      end
    end

    test "the whole response from a client with a default base URL", %{dir: dir} do
      root =
        generate!(Path.join(dir, "default"), %{"/things" => %{"get" => op()}},
          base_url: "https://api.test"
        )

      adapter = fn request -> {request, Req.Response.new(status: 200, body: "ok")} end
      client = Module.concat(root, Client).new(adapter: adapter, return: :response)

      assert {:ok, %Req.Response{body: "ok"}} = Module.concat(root, Things).get_things(client)
      assert client.options.base_url == "https://api.test"
    end

    test "an error for an unknown return option", %{root: root} do
      assert_raise ArgumentError, ~r/return must be :body or :response/, fn ->
        Module.concat(root, Client).new(base_url: "https://api.test", return: :headers)
      end
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

    test "list query parameters as repeated keys, or comma-separated with explode: false", %{
      dir: dir
    } do
      array = %{"type" => "array", "items" => %{"type" => "integer"}}

      params = [
        param("ids", "query", %{"schema" => array}),
        param("tags", "query", %{"schema" => array, "explode" => false}),
        param("q", "query")
      ]

      root = generate!(dir, %{"/things" => %{"get" => op(%{"parameters" => params})}})
      {:ok, sent} = call(root, Things, :get_things, [[ids: [1, 2], tags: [3, 4], q: "x"]])

      assert URI.parse(sent.url).query == "ids=1&ids=2&tags=3%2C4&q=x"
    end

    test "path parameters escaped so they stay one path segment", %{dir: dir} do
      params = [param("id", "path", %{"required" => true})]
      root = generate!(dir, %{"/things/{id}/items" => %{"get" => op(%{"parameters" => params})}})

      {:ok, sent} = call(root, Things, :get_things_id_items, ["a/b c?d#e"])
      assert sent.url == "https://api.test/things/a%2Fb%20c%3Fd%23e/items"

      {:ok, sent} = call(root, Things, :get_things_id_items, [42])
      assert sent.url == "https://api.test/things/42/items"
    end

    test "a form body when that's the only content type", %{dir: dir} do
      root = generate!(dir, body_paths(["application/x-www-form-urlencoded"]))
      {:ok, sent} = call(root, Things, :post_things, [%{name: "a b", size: 1}])

      assert sent.headers["content-type"] == ["application/x-www-form-urlencoded"]
      assert URI.decode_query(sent.body) == %{"name" => "a b", "size" => "1"}
    end

    test "a multipart body", %{dir: dir} do
      root = generate!(dir, body_paths(["multipart/form-data"]))
      {:ok, sent} = call(root, Things, :post_things, [[name: "a"]])

      assert ["multipart/form-data; boundary=" <> _] = sent.headers["content-type"]
      assert sent.body =~ ~s(name="name")
    end

    test "boolean and float multipart fields as strings", %{dir: dir} do
      root = generate!(dir, body_paths(["multipart/form-data"]))

      {:ok, sent} =
        call(root, Things, :post_things, [
          %{active: true, hidden: false, ratio: 1.5, label: {0.25, content_type: "text/plain"}}
        ])

      assert sent.body =~ ~s(name="active"\r\n\r\ntrue\r\n)
      assert sent.body =~ ~s(name="hidden"\r\n\r\nfalse\r\n)
      assert sent.body =~ ~s(name="ratio"\r\n\r\n1.5\r\n)
      assert sent.body =~ ~s(content-type: text/plain\r\n\r\n0.25\r\n)
    end

    test "a raw body with the declared content type", %{dir: dir} do
      root = generate!(dir, body_paths(["application/octet-stream"]))
      {:ok, sent} = call(root, Things, :post_things, [<<1, 2, 3>>])

      assert sent.headers["content-type"] == ["application/octet-stream"]
      assert sent.body == <<1, 2, 3>>
    end

    test "JSON with a +json content type keeps that content type", %{dir: dir} do
      root = generate!(dir, body_paths(["application/vnd.api+json"]))
      {:ok, sent} = call(root, Things, :post_things, [%{data: 1}])

      assert sent.headers["content-type"] == ["application/vnd.api+json"]
      assert Jason.decode!(sent.body) == %{"data" => 1}
    end

    test "JSON when the spec offers JSON alongside other types", %{dir: dir} do
      root = generate!(dir, body_paths(["multipart/form-data", "application/json"]))
      {:ok, sent} = call(root, Things, :post_things, [%{name: "a"}])

      assert sent.headers["content-type"] == ["application/json"]
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
