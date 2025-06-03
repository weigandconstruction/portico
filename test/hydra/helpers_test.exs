defmodule Hydra.HelpersTest do
  use ExUnit.Case, async: true

  alias Hydra.Helpers
  alias Hydra.Spec.Operation
  alias Hydra.Spec.Path, as: SpecPath

  doctest Hydra.Helpers

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

    test "uses first tag when operation has multiple tags" do
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
      assert not Map.has_key?(result, "secondary")
      assert not Map.has_key?(result, "tertiary")
      assert length(result["primary"]) == 1
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
end
