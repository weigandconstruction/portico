defmodule Hydra.Spec.PathTest do
  use ExUnit.Case, async: true

  alias Hydra.Spec.Path

  describe "parse/1" do
    test "parses a simple path with no operations" do
      input = {"/users", %{}}

      path = Path.parse(input)

      assert path.path == "/users"
      assert path.operations == []
      assert path.parameters == []
    end

    test "parses a path with a single GET operation" do
      input =
        {"/users",
         %{
           "get" => %{
             "summary" => "List users",
             "description" => "Returns a list of users"
           }
         }}

      path = Path.parse(input)

      assert path.path == "/users"
      assert length(path.operations) == 1
      assert path.parameters == []

      operation = List.first(path.operations)
      assert operation.method == "get"
      assert operation.summary == "List users"
      assert operation.description == "Returns a list of users"
    end

    test "parses a path with multiple operations" do
      input =
        {"/users",
         %{
           "get" => %{
             "summary" => "List users"
           },
           "post" => %{
             "summary" => "Create user"
           },
           "put" => %{
             "summary" => "Update user"
           },
           "delete" => %{
             "summary" => "Delete user"
           }
         }}

      path = Path.parse(input)

      assert path.path == "/users"
      assert length(path.operations) == 4

      methods = Enum.map(path.operations, & &1.method)
      assert "get" in methods
      assert "post" in methods
      assert "put" in methods
      assert "delete" in methods
    end

    test "parses all valid HTTP methods" do
      input =
        {"/test",
         %{
           "get" => %{"summary" => "GET"},
           "post" => %{"summary" => "POST"},
           "put" => %{"summary" => "PUT"},
           "delete" => %{"summary" => "DELETE"},
           "patch" => %{"summary" => "PATCH"},
           "options" => %{"summary" => "OPTIONS"},
           "head" => %{"summary" => "HEAD"},
           "trace" => %{"summary" => "TRACE"}
         }}

      path = Path.parse(input)

      assert length(path.operations) == 8
      methods = Enum.map(path.operations, & &1.method)
      assert methods == ["trace", "head", "options", "patch", "delete", "put", "post", "get"]
    end

    test "ignores invalid HTTP methods" do
      input =
        {"/test",
         %{
           "get" => %{"summary" => "Valid GET"},
           "invalid_method" => %{"summary" => "Invalid"},
           "custom" => %{"summary" => "Custom"},
           "post" => %{"summary" => "Valid POST"}
         }}

      path = Path.parse(input)

      assert length(path.operations) == 2
      methods = Enum.map(path.operations, & &1.method)
      assert "get" in methods
      assert "post" in methods
      assert "invalid_method" not in methods
      assert "custom" not in methods
    end

    test "parses path-level parameters" do
      input =
        {"/users/{id}",
         %{
           "parameters" => [
             %{
               "name" => "id",
               "in" => "path",
               "required" => true,
               "schema" => %{"type" => "integer"}
             },
             %{
               "name" => "api-version",
               "in" => "header",
               "required" => false,
               "schema" => %{"type" => "string"}
             }
           ],
           "get" => %{
             "summary" => "Get user"
           }
         }}

      path = Path.parse(input)

      assert path.path == "/users/{id}"
      assert length(path.parameters) == 2
      assert length(path.operations) == 1

      parameters_by_name = Enum.into(path.parameters, %{}, fn param -> {param.name, param} end)

      id_param = parameters_by_name["id"]
      assert id_param.name == "id"
      assert id_param.in == "path"
      assert id_param.required == true

      version_param = parameters_by_name["api-version"]
      assert version_param.name == "api-version"
      assert version_param.in == "header"
      assert version_param.required == false
    end

    test "handles empty parameters array" do
      input =
        {"/users",
         %{
           "parameters" => [],
           "get" => %{"summary" => "Get users"}
         }}

      path = Path.parse(input)

      assert path.path == "/users"
      assert path.parameters == []
      assert length(path.operations) == 1
    end

    test "handles missing parameters field" do
      input =
        {"/users",
         %{
           "get" => %{"summary" => "Get users"}
         }}

      path = Path.parse(input)

      assert path.path == "/users"
      assert path.parameters == []
      assert length(path.operations) == 1
    end

    test "parses complex path with operations and parameters" do
      input =
        {"/projects/{project_id}/tasks/{task_id}",
         %{
           "parameters" => [
             %{
               "name" => "project_id",
               "in" => "path",
               "required" => true,
               "schema" => %{"type" => "string"}
             }
           ],
           "get" => %{
             "summary" => "Get task",
             "parameters" => [
               %{
                 "name" => "task_id",
                 "in" => "path",
                 "required" => true,
                 "schema" => %{"type" => "integer"}
               }
             ]
           },
           "put" => %{
             "summary" => "Update task",
             "requestBody" => %{
               "content" => %{
                 "application/json" => %{
                   "schema" => %{"$ref" => "#/components/schemas/Task"}
                 }
               }
             }
           }
         }}

      path = Path.parse(input)

      assert path.path == "/projects/{project_id}/tasks/{task_id}"
      assert length(path.parameters) == 1
      assert length(path.operations) == 2

      # Check path-level parameter
      path_param = List.first(path.parameters)
      assert path_param.name == "project_id"
      assert path_param.in == "path"

      # Check operations
      operations_by_method = Enum.into(path.operations, %{}, fn op -> {op.method, op} end)

      get_op = operations_by_method["get"]
      assert get_op.summary == "Get task"
      assert length(get_op.parameters) == 1

      put_op = operations_by_method["put"]
      assert put_op.summary == "Update task"
      assert put_op.request_body != nil
    end
  end
end
