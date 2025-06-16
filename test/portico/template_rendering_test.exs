defmodule Portico.TemplateRenderingTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Portico.Spec.{Operation, Parameter, Response}
  alias Portico.Spec.Path, as: SpecPath

  @moduletag :template_rendering

  setup do
    # Create a temporary directory for testing
    {:ok, temp_dir} = Briefly.create(type: :directory)
    %{temp_dir: temp_dir}
  end

  describe "generated function signatures" do
    test "generates correct signature for operation with no parameters", %{temp_dir: temp_dir} do
      spec =
        create_test_spec([
          create_path("/simple", [
            create_operation("get", "simple-tag", "Simple operation")
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/simple_tag.ex"))
      assert content =~ "def get_simple(client)"
      refute content =~ "opts \\\\ []"
    end

    test "generates correct signature for operation with required parameters", %{
      temp_dir: temp_dir
    } do
      path_params = [
        %Parameter{name: "id", internal_name: "id", in: "path", required: true}
      ]

      operation_params = [
        %Parameter{name: "company-id", internal_name: "company_id", in: "header", required: true}
      ]

      spec =
        create_test_spec([
          create_path(
            "/users/{id}",
            [
              create_operation("get", "users", "Get user", operation_params)
            ],
            path_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def get_users_id(client, id, companyid)"
      refute content =~ "opts \\\\ []"
    end

    test "generates correct signature for operation with optional parameters", %{
      temp_dir: temp_dir
    } do
      operation_params = [
        %Parameter{name: "limit", internal_name: "limit", in: "query", required: false},
        %Parameter{name: "offset", internal_name: "offset", in: "query", required: false}
      ]

      spec =
        create_test_spec([
          create_path("/users", [
            create_operation("get", "users", "List users", operation_params)
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def get_users(client, opts \\\\ [])"
    end

    test "generates correct signature for operation with both required and optional parameters",
         %{temp_dir: temp_dir} do
      required_params = [
        %Parameter{name: "id", internal_name: "id", in: "path", required: true}
      ]

      optional_params = [
        %Parameter{name: "fields", internal_name: "fields", in: "query", required: false}
      ]

      spec =
        create_test_spec([
          create_path(
            "/users/{id}",
            [
              create_operation("get", "users", "Get user", optional_params)
            ],
            required_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def get_users_id(client, id, opts \\\\ [])"
    end

    test "generates correct signature for operation with request body", %{temp_dir: temp_dir} do
      operation = %Operation{
        method: "post",
        tags: ["users"],
        summary: "Create user",
        request_body: %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{"type" => "object"}
            }
          }
        }
      }

      spec =
        create_test_spec([
          %SpecPath{path: "/users", operations: [operation]}
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def post_users(client, body)"
    end

    test "generates correct signature for operation with request body and parameters", %{
      temp_dir: temp_dir
    } do
      required_params = [
        %Parameter{name: "company-id", internal_name: "company_id", in: "header", required: true}
      ]

      optional_params = [
        %Parameter{name: "validate", internal_name: "validate", in: "query", required: false}
      ]

      operation = %Operation{
        method: "post",
        tags: ["users"],
        summary: "Create user",
        parameters: required_params ++ optional_params,
        request_body: %{
          "required" => true,
          "content" => %{"application/json" => %{"schema" => %{"type" => "object"}}}
        }
      }

      spec =
        create_test_spec([
          %SpecPath{path: "/users", operations: [operation]}
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def post_users(client, companyid, body, opts \\\\ [])"
    end
  end

  describe "generated HTTP request parameters" do
    test "generates correct URL with path parameters", %{temp_dir: temp_dir} do
      path_params = [
        %Parameter{name: "company_id", internal_name: "company_id", in: "path", required: true},
        %Parameter{name: "project_id", internal_name: "project_id", in: "path", required: true}
      ]

      spec =
        create_test_spec([
          create_path(
            "/companies/{company_id}/projects/{project_id}",
            [
              create_operation("get", "projects", "Get project")
            ],
            path_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/projects.ex"))
      assert content =~ "url: \"/companies/\#{company_id}/projects/\#{project_id}\""
    end

    test "converts camelCase parameter names to snake_case in URLs", %{temp_dir: temp_dir} do
      # This test specifically covers the bug fix for parameter name interpolation
      path_params = [
        %Parameter{name: "assetId", internal_name: "asset_id", in: "path", required: true},
        %Parameter{
          name: "historyServiceId",
          internal_name: "history_service_id",
          in: "path",
          required: true
        }
      ]

      spec =
        create_test_spec([
          create_path(
            "/assets/{assetId}/history-services/{historyServiceId}",
            [
              create_operation("get", "asset_services", "Get asset history service")
            ],
            path_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/asset_services.ex"))

      # Should use snake_case parameter names in URL interpolation
      assert content =~ "url: \"/assets/\#{asset_id}/history-services/\#{history_service_id}\""

      # Should NOT contain the original camelCase names
      refute content =~ ~r/\#{assetId}/
      refute content =~ ~r/\#{historyServiceId}/

      # Function signature should also use snake_case (accounting for line breaks)
      assert content =~ "def get_assets_asset_id_history_services_history_service_id("
      assert content =~ "asset_id,"
      assert content =~ "history_service_id"
    end

    test "handles complex camelCase to snake_case conversions", %{temp_dir: temp_dir} do
      path_params = [
        %Parameter{name: "companyId", internal_name: "company_id", in: "path", required: true},
        %Parameter{
          name: "projectItemId",
          internal_name: "project_item_id",
          in: "path",
          required: true
        },
        %Parameter{
          name: "subItemUUID",
          internal_name: "sub_item_uuid",
          in: "path",
          required: true
        }
      ]

      spec =
        create_test_spec([
          create_path(
            "/companies/{companyId}/projects/{projectItemId}/sub-items/{subItemUUID}",
            [
              create_operation("delete", "projects", "Delete project sub-item")
            ],
            path_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/projects.ex"))

      # All parameter names should be converted to snake_case
      assert content =~
               "url: \"/companies/\#{company_id}/projects/\#{project_item_id}/sub-items/\#{sub_item_uuid}\""

      # Original camelCase should not appear
      refute content =~ ~r/\#{companyId}/
      refute content =~ ~r/\#{projectItemId}/
      refute content =~ ~r/\#{subItemUUID}/

      # Function signature should use snake_case (accounting for line breaks and truncation)
      assert content =~
               "def delete_companies_company_id_projects_project_item_id_sub_items_sub_item_uui"

      assert content =~ "company_id,"
      assert content =~ "project_item_id,"
      assert content =~ "sub_item_uuid"
    end

    test "handles parameters that are already snake_case", %{temp_dir: temp_dir} do
      path_params = [
        %Parameter{name: "user_id", internal_name: "user_id", in: "path", required: true},
        %Parameter{name: "post_id", internal_name: "post_id", in: "path", required: true}
      ]

      spec =
        create_test_spec([
          create_path(
            "/users/{user_id}/posts/{post_id}",
            [
              create_operation("get", "posts", "Get user post")
            ],
            path_params
          )
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/posts.ex"))

      # Should work correctly with already snake_case parameters
      assert content =~ "url: \"/users/\#{user_id}/posts/\#{post_id}\""
      assert content =~ "def get_users_user_id_posts_post_id(client, user_id, post_id)"
    end

    test "generates correct headers for header parameters", %{temp_dir: temp_dir} do
      header_params = [
        %Parameter{
          name: "Authorization",
          internal_name: "authorization",
          in: "header",
          required: true
        },
        %Parameter{
          name: "X-Custom-Header",
          internal_name: "x_custom_header",
          in: "header",
          required: false
        }
      ]

      spec =
        create_test_spec([
          create_path("/protected", [
            create_operation("get", "auth", "Protected endpoint", header_params)
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/auth.ex"))
      assert content =~ "headers: ["
      assert content =~ "{\"Authorization\", authorization},"
      assert content =~ "{\"X-Custom-Header\", Keyword.get(opts, :x_custom_header)}"
    end

    test "generates correct query parameters", %{temp_dir: temp_dir} do
      query_params = [
        %Parameter{name: "limit", internal_name: "limit", in: "query", required: true},
        %Parameter{name: "offset", internal_name: "offset", in: "query", required: false},
        %Parameter{name: "filter", internal_name: "filter", in: "query", required: false}
      ]

      spec =
        create_test_spec([
          create_path("/search", [
            create_operation("get", "search", "Search endpoint", query_params)
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/search.ex"))
      assert content =~ "params: ["
      assert content =~ "{\"limit\", limit}"
      assert content =~ "{\"offset\", Keyword.get(opts, :offset)}"
      assert content =~ "{\"filter\", Keyword.get(opts, :filter)}"
    end

    test "generates correct request body handling", %{temp_dir: temp_dir} do
      operation = %Operation{
        method: "post",
        tags: ["data"],
        summary: "Submit data",
        request_body: %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{"type" => "object"}
            }
          }
        }
      }

      spec =
        create_test_spec([
          %SpecPath{path: "/data", operations: [operation]}
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/data.ex"))
      assert content =~ "json: body"
    end

    test "generates correct HTTP method", %{temp_dir: temp_dir} do
      methods = ["get", "post", "put", "delete", "patch"]

      for method <- methods do
        spec =
          create_test_spec([
            create_path("/test", [
              create_operation(method, "test", "Test #{method}")
            ])
          ])

        generate_and_test(spec, temp_dir, "TestAPI")

        content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/test.ex"))
        assert content =~ "method: :#{method}"

        # Clean up for next iteration
        File.rm_rf!(Elixir.Path.join(temp_dir, "lib"))
      end
    end
  end

  describe "generated documentation" do
    test "includes operation summary and description", %{temp_dir: temp_dir} do
      spec =
        create_test_spec([
          create_path("/users", [
            %Operation{
              method: "get",
              tags: ["users"],
              summary: "List all users",
              description: "Returns a paginated list of all users in the system"
            }
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "@doc \"\"\""
      assert content =~ "Returns a paginated list of all users in the system"
    end

    test "includes parameter documentation", %{temp_dir: temp_dir} do
      params = [
        %Parameter{
          name: "limit",
          internal_name: "limit",
          in: "query",
          required: false,
          description: "Maximum number of results to return",
          schema: %{"type" => "integer"}
        },
        %Parameter{
          name: "user_id",
          internal_name: "user_id",
          in: "path",
          required: true,
          description: "Unique identifier for the user",
          schema: %{"type" => "string"}
        }
      ]

      spec =
        create_test_spec([
          create_path("/users/{user_id}", [
            create_operation("get", "users", "Get user", params)
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "## Parameters"
      assert content =~ "`user_id` - `string` (required) - Unique identifier for the user"
      assert content =~ "`limit` - `integer` (optional) - Maximum number of results to return"
    end

    test "includes request body documentation", %{temp_dir: temp_dir} do
      operation = %Operation{
        method: "post",
        tags: ["users"],
        summary: "Create user",
        request_body: %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string", "description" => "User's full name"},
                  "email" => %{"type" => "string", "description" => "User's email address"}
                },
                "required" => ["name"]
              }
            }
          }
        }
      }

      spec =
        create_test_spec([
          %SpecPath{path: "/users", operations: [operation]}
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "## Parameters"
      assert content =~ "`body` - `object` (required) - Request body parameters"
      assert content =~ "`name` - `string` (required) - User's full name"
      assert content =~ "`email` - `string` (optional) - User's email address"
    end
  end

  describe "unique function names" do
    test "generates unique function names for operations in same module", %{temp_dir: temp_dir} do
      spec =
        create_test_spec([
          create_path("/users", [
            create_operation("get", "users", "List users")
          ]),
          create_path("/users/{id}", [
            create_operation("get", "users", "Get user")
          ]),
          create_path("/users/{id}/posts", [
            create_operation("get", "users", "Get user posts")
          ])
        ])

      generate_and_test(spec, temp_dir, "TestAPI")

      content = File.read!(Elixir.Path.join(temp_dir, "lib/test_api/api/users.ex"))
      assert content =~ "def get_users(client"
      assert content =~ "def get_users_id(client"
      assert content =~ "def get_users_id_posts(client"

      # Ensure all three functions are present and unique
      get_users_count = (content |> String.split("def get_users(") |> length()) - 1
      get_users_id_count = (content |> String.split("def get_users_id(") |> length()) - 1

      get_users_id_posts_count =
        (content |> String.split("def get_users_id_posts(") |> length()) - 1

      assert get_users_count == 1
      assert get_users_id_count == 1
      assert get_users_id_posts_count == 1
    end
  end

  # Helper functions
  defp create_test_spec(paths) do
    %Portico.Spec{
      version: "3.0.0",
      info: %{"title" => "Test API", "version" => "1.0.0"},
      paths: paths
    }
  end

  defp create_path(path, operations, parameters \\ []) do
    %SpecPath{
      path: path,
      operations: operations,
      parameters: parameters
    }
  end

  defp create_operation(method, tag, summary, parameters \\ []) do
    %Operation{
      method: method,
      tags: [tag],
      summary: summary,
      parameters: parameters,
      responses: %{
        "200" => %Response{description: "Success"}
      }
    }
  end

  defp generate_and_test(spec, temp_dir, module_name) do
    # Write spec to file
    spec_json = %{
      "openapi" => spec.version,
      "info" => spec.info,
      "paths" => paths_to_json(spec.paths)
    }

    spec_file = Elixir.Path.join(temp_dir, "test_spec.json")
    File.write!(spec_file, Jason.encode!(spec_json))

    # Generate code in temp directory context
    File.cd!(temp_dir, fn ->
      capture_io(fn ->
        Mix.Tasks.Portico.Generate.run(["--module", module_name, "--spec", spec_file])
      end)
    end)
  end

  defp paths_to_json(paths) do
    Enum.into(paths, %{}, fn path ->
      operations_json =
        Enum.into(path.operations, %{}, fn op ->
          {op.method, operation_to_json(op)}
        end)

      path_json =
        if path.parameters != [] do
          Map.put(operations_json, "parameters", Enum.map(path.parameters, &parameter_to_json/1))
        else
          operations_json
        end

      {path.path, path_json}
    end)
  end

  defp operation_to_json(operation) do
    json = %{
      "summary" => operation.summary,
      "tags" => operation.tags
    }

    json =
      if operation.description do
        Map.put(json, "description", operation.description)
      else
        json
      end

    json =
      if operation.parameters != [] do
        Map.put(json, "parameters", Enum.map(operation.parameters, &parameter_to_json/1))
      else
        json
      end

    json =
      if operation.request_body do
        Map.put(json, "requestBody", operation.request_body)
      else
        json
      end

    json =
      if operation.responses != %{} do
        responses_json =
          Enum.into(operation.responses, %{}, fn {code, response} ->
            {code, %{"description" => response.description}}
          end)

        Map.put(json, "responses", responses_json)
      else
        json
      end

    json
  end

  defp parameter_to_json(parameter) do
    json = %{
      "name" => parameter.name,
      "in" => parameter.in,
      "required" => parameter.required
    }

    json =
      if parameter.description do
        Map.put(json, "description", parameter.description)
      else
        json
      end

    json =
      if parameter.schema do
        Map.put(json, "schema", parameter.schema)
      else
        json
      end

    json
  end
end
