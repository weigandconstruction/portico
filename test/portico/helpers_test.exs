defmodule Portico.HelpersTest do
  use ExUnit.Case, async: true

  alias Portico.Helpers
  alias Portico.Spec.Operation
  alias Portico.Spec.Path, as: SpecPath

  doctest Portico.Helpers

  describe "friendly_name/1" do
    test "handles basic paths" do
      assert Helpers.friendly_name("/users/{id}") == "users_id"
      assert Helpers.friendly_name("/api/v1/posts") == "api_v1_posts"
    end

    test "handles OData-style paths with parentheses, equals, and quotes" do
      assert Helpers.friendly_name("/users(userPrincipalName='{user_principal_name}')") ==
               "usersuser_principal_nameuser_principal_name"

      assert Helpers.friendly_name("/items(key='value')") == "itemskeyvalue"
      assert Helpers.friendly_name("/test(id='{test_id}')") == "testidtest_id"
    end

    test "handles complex paths with multiple special characters" do
      assert Helpers.friendly_name("/api/v1.0/users(userPrincipalName='{upn}')/messages") ==
               "api_v1_0_usersuser_principal_nameupn_messages"

      assert Helpers.friendly_name("/test(a='1',b=\"2\")/endpoint") == "testa1b2_endpoint"
    end

    test "handles $ characters in paths" do
      assert Helpers.friendly_name("/users/$count") == "users_count"
      assert Helpers.friendly_name("/api/v1.0/users/$metadata") == "api_v1_0_users_metadata"
      assert Helpers.friendly_name("/endpoints/$batch") == "endpoints_batch"
    end

    test "handles complex Microsoft Graph style paths" do
      assert Helpers.friendly_name(
               "/users/{user-id}/ownedDevices/microsoft.graph.endpoint/$count"
             ) == "users_user_id_owned_devices_microsoft_graph_endpoint_count"

      assert Helpers.friendly_name(
               "/users(userPrincipalName='{user_principal_name}')/$links/manager"
             ) == "usersuser_principal_nameuser_principal_name_links_manager"
    end

    test "handles edge cases with consecutive special characters" do
      assert Helpers.friendly_name("/test(){}[]$/-") == "test"
      assert Helpers.friendly_name("///test///") == "test"
      assert Helpers.friendly_name("/{{{test}}}") == "test"
    end
  end

  describe "tag_to_module_name/1" do
    test "converts simple tags to module names" do
      assert Helpers.tag_to_module_name("users") == "Users"
      assert Helpers.tag_to_module_name("user-management") == "UserManagement"
      assert Helpers.tag_to_module_name("simple_tag") == "SimpleTag"
    end

    test "handles hierarchical tags with slashes" do
      assert Helpers.tag_to_module_name("Core/Workflows/workflow-tools") ==
               "CoreWorkflowsWorkflowTools"

      assert Helpers.tag_to_module_name("Project/Management/daily-log") ==
               "ProjectManagementDailyLog"
    end

    test "handles special characters and spaces" do
      assert Helpers.tag_to_module_name("Quality & Safety/punch-list") == "QualitySafetyPunchList"

      assert Helpers.tag_to_module_name("Construction Financials/budget") ==
               "ConstructionFinancialsBudget"

      assert Helpers.tag_to_module_name("API/v2.0/endpoints") == "APIV20Endpoints"
    end

    test "removes invalid characters" do
      assert Helpers.tag_to_module_name("tag@with#symbols$") == "Tagwithsymbols"
      assert Helpers.tag_to_module_name("tag(with)parentheses") == "Tagwithparentheses"
      assert Helpers.tag_to_module_name("tag[with]brackets") == "Tagwithbrackets"
    end

    test "handles empty and nil values" do
      assert Helpers.tag_to_module_name("") == ""
    end

    test "handles tags starting with numbers" do
      assert Helpers.tag_to_module_name("1-Click Applications") == "N1ClickApplications"
      assert Helpers.tag_to_module_name("2FA/authentication") == "N2FAAuthentication"
      assert Helpers.tag_to_module_name("3rd-party-integrations") == "N3rdPartyIntegrations"
      assert Helpers.tag_to_module_name("404-handlers") == "N404Handlers"
    end
  end

  describe "tag_to_filename/1" do
    test "converts simple tags to filenames" do
      assert Helpers.tag_to_filename("users") == "users"
      assert Helpers.tag_to_filename("user-management") == "user_management"
      assert Helpers.tag_to_filename("simple_tag") == "simple_tag"
    end

    test "handles hierarchical tags with slashes" do
      assert Helpers.tag_to_filename("Core/Workflows/workflow-tools") ==
               "core_workflows_workflow_tools"

      assert Helpers.tag_to_filename("Project/Management/daily-log") ==
               "project_management_daily_log"
    end

    test "handles special characters and spaces" do
      assert Helpers.tag_to_filename("Quality & Safety/punch-list") == "quality_safety_punch_list"

      assert Helpers.tag_to_filename("Construction Financials/budget") ==
               "construction_financials_budget"

      assert Helpers.tag_to_filename("API/v2.0/endpoints") == "api_v20_endpoints"
    end

    test "removes invalid characters and normalizes" do
      assert Helpers.tag_to_filename("tag@with#symbols$") == "tagwithsymbols"
      assert Helpers.tag_to_filename("tag(with)parentheses") == "tagwithparentheses"
      assert Helpers.tag_to_filename("tag[with]brackets") == "tagwithbrackets"
    end

    test "handles multiple consecutive separators" do
      assert Helpers.tag_to_filename("tag---with___multiple") == "tag_with_multiple"
      assert Helpers.tag_to_filename("tag///with\\\\\\separators") == "tag_withseparators"
    end

    test "handles empty and nil values" do
      assert Helpers.tag_to_filename("") == ""
    end

    test "handles tags starting with numbers" do
      assert Helpers.tag_to_filename("1-Click Applications") == "n1_click_applications"
      assert Helpers.tag_to_filename("2FA/authentication") == "n2fa_authentication"
      assert Helpers.tag_to_filename("3rd-party-integrations") == "n3rd_party_integrations"
      assert Helpers.tag_to_filename("404-handlers") == "n404_handlers"
    end
  end

  describe "group_operations_by_tag/1" do
    test "groups operations by their first tag" do
      paths = [
        %SpecPath{
          path: "/users",
          operations: [
            %Operation{tags: ["user-management"], method: "get"},
            %Operation{tags: ["user-management"], method: "post"}
          ]
        },
        %SpecPath{
          path: "/posts",
          operations: [
            %Operation{tags: ["content"], method: "get"},
            %Operation{tags: ["content", "moderation"], method: "delete"}
          ]
        }
      ]

      result = Helpers.group_operations_by_tag(paths)

      assert Map.has_key?(result, "user-management")
      assert Map.has_key?(result, "content")
      assert length(result["user-management"]) == 2
      assert length(result["content"]) == 2
    end

    test "includes operation under all tags when operation has multiple tags" do
      paths = [
        %SpecPath{
          path: "/items",
          operations: [
            %Operation{tags: ["primary", "secondary", "tertiary"], method: "get"}
          ]
        }
      ]

      result = Helpers.group_operations_by_tag(paths)

      assert Map.has_key?(result, "primary")
      assert Map.has_key?(result, "secondary")
      assert Map.has_key?(result, "tertiary")
      assert length(result["primary"]) == 1
      assert length(result["secondary"]) == 1
      assert length(result["tertiary"]) == 1

      # Verify the same operation appears under each tag
      [{path1, op1}] = result["primary"]
      [{path2, op2}] = result["secondary"]
      [{path3, op3}] = result["tertiary"]
      assert path1.path == "/items"
      assert path2.path == "/items"
      assert path3.path == "/items"
      assert op1.method == "get"
      assert op2.method == "get"
      assert op3.method == "get"
    end

    test "falls back to path when no tags are present" do
      paths = [
        %SpecPath{
          path: "/no-tags",
          operations: [
            %Operation{tags: [], method: "get"}
          ]
        },
        %SpecPath{
          path: "/also-no-tags",
          operations: [
            %Operation{tags: [], method: "post"}
          ]
        }
      ]

      result = Helpers.group_operations_by_tag(paths)

      assert Map.has_key?(result, "/no-tags")
      assert Map.has_key?(result, "/also-no-tags")
      assert length(result["/no-tags"]) == 1
      assert length(result["/also-no-tags"]) == 1
    end

    test "mixes tagged and untagged operations" do
      paths = [
        %SpecPath{
          path: "/tagged",
          operations: [
            %Operation{tags: ["api"], method: "get"}
          ]
        },
        %SpecPath{
          path: "/untagged",
          operations: [
            %Operation{tags: [], method: "get"}
          ]
        }
      ]

      result = Helpers.group_operations_by_tag(paths)

      assert Map.has_key?(result, "api")
      assert Map.has_key?(result, "/untagged")
      assert length(result["api"]) == 1
      assert length(result["/untagged"]) == 1
    end

    test "handles empty paths list" do
      result = Helpers.group_operations_by_tag([])
      assert result == %{}
    end

    test "handles paths with no operations" do
      paths = [
        %SpecPath{path: "/empty", operations: []}
      ]

      result = Helpers.group_operations_by_tag(paths)
      assert result == %{}
    end

    test "preserves path and operation data in tuples" do
      path = %SpecPath{
        path: "/test",
        operations: [
          %Operation{tags: ["test-tag"], method: "get", summary: "Test operation"}
        ]
      }

      result = Helpers.group_operations_by_tag([path])

      [{returned_path, returned_operation}] = result["test-tag"]
      assert returned_path == path
      assert returned_operation.method == "get"
      assert returned_operation.summary == "Test operation"
    end
  end

  describe "function_name_for_operation/2" do
    test "creates function name from method and path" do
      path = %SpecPath{path: "/users/{id}"}
      operation = %Operation{method: "get"}

      result = Helpers.function_name_for_operation(path, operation)
      assert result == "get_users_id"
    end

    test "handles complex paths" do
      path = %SpecPath{path: "/rest/v2.0/companies/{company_id}/projects/{project_id}"}
      operation = %Operation{method: "post"}

      result = Helpers.function_name_for_operation(path, operation)
      assert result == "post_rest_v2_0_companies_company_id_projects_project_id"
    end

    test "handles paths with special characters" do
      path = %SpecPath{path: "/api/v1.0/resources-with-dashes"}
      operation = %Operation{method: "put"}

      result = Helpers.function_name_for_operation(path, operation)
      assert result == "put_api_v1_0_resources_with_dashes"
    end

    test "handles paths with OData-style parameters" do
      path = %SpecPath{path: "/users(userPrincipalName='{user_principal_name}')"}
      operation = %Operation{method: "patch"}

      result = Helpers.function_name_for_operation(path, operation)
      assert result == "patch_usersuser_principal_nameuser_principal_name"
    end

    test "handles paths with parentheses, equals signs, and quotes" do
      path = %SpecPath{path: "/test(key='value')/endpoint"}
      operation = %Operation{method: "get"}

      result = Helpers.function_name_for_operation(path, operation)
      assert result == "get_testkeyvalue_endpoint"
    end

    test "works with all HTTP methods" do
      path = %SpecPath{path: "/test"}
      methods = ["get", "post", "put", "delete", "patch", "options", "head", "trace"]

      for method <- methods do
        operation = %Operation{method: method}
        result = Helpers.function_name_for_operation(path, operation)
        assert result == "#{method}_test"
      end
    end
  end

  describe "interpolated_path_with_params/2" do
    alias Portico.Spec.Parameter

    test "interpolates single path parameter with snake_case conversion" do
      path = "/assets/{assetId}"

      params = [
        %Parameter{name: "assetId", internal_name: "asset_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/assets/\#{asset_id}"
    end

    test "interpolates multiple path parameters" do
      path = "/assets/{assetId}/history-services/{historyServiceId}"

      params = [
        %Parameter{name: "assetId", internal_name: "asset_id", in: "path"},
        %Parameter{name: "historyServiceId", internal_name: "history_service_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/assets/\#{asset_id}/history-services/\#{history_service_id}"
    end

    test "ignores non-path parameters" do
      path = "/users/{userId}"

      params = [
        %Parameter{name: "userId", internal_name: "user_id", in: "path"},
        %Parameter{name: "limit", internal_name: "limit", in: "query"},
        %Parameter{name: "Authorization", internal_name: "authorization", in: "header"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/users/\#{user_id}"
    end

    test "handles paths with no parameters" do
      path = "/users"

      params = [
        %Parameter{name: "limit", internal_name: "limit", in: "query"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/users"
    end

    test "handles empty parameter list" do
      path = "/users/{id}"
      params = []

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/users/{id}"
    end

    test "handles complex parameter names with underscores and numbers" do
      path = "/api/v2/{companyId}/items/{itemId123}/sub-items/{subItemId}"

      params = [
        %Parameter{name: "companyId", internal_name: "company_id", in: "path"},
        %Parameter{name: "itemId123", internal_name: "item_id123", in: "path"},
        %Parameter{name: "subItemId", internal_name: "sub_item_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/api/v2/\#{company_id}/items/\#{item_id123}/sub-items/\#{sub_item_id}"
    end

    test "handles parameters that don't appear in path" do
      path = "/users/{userId}"

      params = [
        %Parameter{name: "userId", internal_name: "user_id", in: "path"},
        %Parameter{name: "nonExistentId", internal_name: "non_existent_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/users/\#{user_id}"
    end

    test "handles parameters with same original and internal names" do
      path = "/posts/{post_id}/comments/{comment_id}"

      params = [
        %Parameter{name: "post_id", internal_name: "post_id", in: "path"},
        %Parameter{name: "comment_id", internal_name: "comment_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/posts/\#{post_id}/comments/\#{comment_id}"
    end

    test "handles duplicate parameter names (should use first occurrence)" do
      path = "/resources/{resourceId}"

      params = [
        %Parameter{name: "resourceId", internal_name: "resource_id", in: "path"},
        %Parameter{name: "resourceId", internal_name: "duplicate_resource_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/resources/\#{resource_id}"
    end

    test "real-world example from unite spec" do
      path = "/quantity-item-allocations/{allocationId}/status-change"

      params = [
        %Parameter{name: "allocationId", internal_name: "allocation_id", in: "path"}
      ]

      result = Helpers.interpolated_path_with_params(path, params)
      assert result == "/quantity-item-allocations/\#{allocation_id}/status-change"
    end
  end

  describe "schema_to_typespec/1" do
    test "converts string schema to String.t()" do
      schema = %{"type" => "string"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "String.t()"
    end

    test "converts integer schema to integer()" do
      schema = %{"type" => "integer"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "integer()"
    end

    test "converts number schema to float()" do
      schema = %{"type" => "number"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "float()"
    end

    test "converts boolean schema to boolean()" do
      schema = %{"type" => "boolean"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "boolean()"
    end

    test "converts array schema to list()" do
      schema = %{"type" => "array"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "list()"
    end

    test "converts object schema to map()" do
      schema = %{"type" => "object"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "map()"
    end

    test "handles nil schema" do
      result = Helpers.schema_to_typespec(nil)
      assert result == "any()"
    end

    test "handles unknown schema types" do
      schema = %{"type" => "unknown"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "any()"
    end

    test "handles schema without type field" do
      schema = %{"description" => "some field"}
      result = Helpers.schema_to_typespec(schema)
      assert result == "any()"
    end
  end

  describe "function_typespec/3" do
    alias Portico.Spec.Parameter

    test "generates typespec for function with no parameters" do
      path = %SpecPath{path: "/users", parameters: []}
      operation = %Operation{method: "get", parameters: [], request_body: nil}

      result = Helpers.function_typespec("get_users", path, operation)

      assert result ==
               "@spec get_users(Req.Request.t()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "generates typespec for function with required path parameter" do
      path = %SpecPath{
        path: "/users/{id}",
        parameters: [
          %Parameter{
            name: "id",
            internal_name: "id",
            in: "path",
            required: true,
            schema: %{"type" => "string"}
          }
        ]
      }

      operation = %Operation{method: "get", parameters: [], request_body: nil}

      result = Helpers.function_typespec("get_users_id", path, operation)

      assert result ==
               "@spec get_users_id(Req.Request.t(), String.t()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "generates typespec for function with multiple required parameters" do
      path = %SpecPath{
        path: "/users/{user_id}/posts/{post_id}",
        parameters: [
          %Parameter{
            name: "user_id",
            internal_name: "user_id",
            in: "path",
            required: true,
            schema: %{"type" => "string"}
          },
          %Parameter{
            name: "post_id",
            internal_name: "post_id",
            in: "path",
            required: true,
            schema: %{"type" => "integer"}
          }
        ]
      }

      operation = %Operation{method: "get", parameters: [], request_body: nil}

      result = Helpers.function_typespec("get_users_user_id_posts_post_id", path, operation)

      assert result ==
               "@spec get_users_user_id_posts_post_id(Req.Request.t(), String.t(), integer()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "generates typespec for function with request body" do
      path = %SpecPath{path: "/users", parameters: []}

      operation = %Operation{
        method: "post",
        parameters: [],
        request_body: %{
          "content" => %{"application/json" => %{"schema" => %{"type" => "object"}}}
        }
      }

      result = Helpers.function_typespec("post_users", path, operation)

      assert result ==
               "@spec post_users(Req.Request.t(), map()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "generates typespec for function with optional parameters" do
      path = %SpecPath{path: "/users", parameters: []}

      operation = %Operation{
        method: "get",
        parameters: [
          %Parameter{
            name: "limit",
            internal_name: "limit",
            in: "query",
            required: false,
            schema: %{"type" => "integer"}
          }
        ],
        request_body: nil
      }

      result = Helpers.function_typespec("get_users", path, operation)

      assert result ==
               "@spec get_users(Req.Request.t(), keyword()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "generates typespec for function with required params, body, and optional params" do
      path = %SpecPath{
        path: "/users/{id}",
        parameters: [
          %Parameter{
            name: "id",
            internal_name: "id",
            in: "path",
            required: true,
            schema: %{"type" => "string"}
          }
        ]
      }

      operation = %Operation{
        method: "put",
        parameters: [
          %Parameter{
            name: "include_metadata",
            internal_name: "include_metadata",
            in: "query",
            required: false,
            schema: %{"type" => "boolean"}
          }
        ],
        request_body: %{
          "content" => %{"application/json" => %{"schema" => %{"type" => "object"}}}
        }
      }

      result = Helpers.function_typespec("put_users_id", path, operation)

      assert result ==
               "@spec put_users_id(Req.Request.t(), String.t(), map(), keyword()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "handles parameters with different schema types" do
      path = %SpecPath{path: "/test", parameters: []}

      operation = %Operation{
        method: "post",
        parameters: [
          %Parameter{
            name: "count",
            internal_name: "count",
            in: "query",
            required: true,
            schema: %{"type" => "integer"}
          },
          %Parameter{
            name: "active",
            internal_name: "active",
            in: "query",
            required: true,
            schema: %{"type" => "boolean"}
          },
          %Parameter{
            name: "tags",
            internal_name: "tags",
            in: "query",
            required: true,
            schema: %{"type" => "array"}
          }
        ],
        request_body: nil
      }

      result = Helpers.function_typespec("post_test", path, operation)

      assert result ==
               "@spec post_test(Req.Request.t(), integer(), boolean(), list()) :: {:ok, any()} | {:error, Exception.t()}"
    end

    test "handles parameters with nil or missing schema" do
      path = %SpecPath{path: "/test", parameters: []}

      operation = %Operation{
        method: "get",
        parameters: [
          %Parameter{
            name: "param1",
            internal_name: "param1",
            in: "query",
            required: true,
            schema: nil
          },
          %Parameter{
            name: "param2",
            internal_name: "param2",
            in: "query",
            required: true,
            schema: %{"description" => "no type"}
          }
        ],
        request_body: nil
      }

      result = Helpers.function_typespec("get_test", path, operation)

      assert result ==
               "@spec get_test(Req.Request.t(), any(), any()) :: {:ok, any()} | {:error, Exception.t()}"
    end
  end
end
