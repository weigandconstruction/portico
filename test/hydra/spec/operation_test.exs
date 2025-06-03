defmodule Hydra.Spec.OperationTest do
  use ExUnit.Case, async: true

  alias Hydra.Spec.Operation

  describe "parse/1" do
    test "parses a minimal operation" do
      input = %{
        "method" => "get"
      }

      operation = Operation.parse(input)

      assert operation.method == "get"
      assert operation.id == nil
      assert operation.summary == nil
      assert operation.description == nil
      assert operation.tags == []
      assert operation.parameters == []
      assert operation.responses == %{}
      assert operation.security == %{}
      assert operation.request_body == nil
    end

    test "parses a complete operation with all fields" do
      input = %{
        "method" => "post",
        "operationId" => "createUser",
        "summary" => "Create a new user",
        "description" => "Creates a new user account in the system",
        "tags" => ["users", "authentication"],
        "parameters" => [
          %{
            "name" => "api-version",
            "in" => "header",
            "required" => false,
            "schema" => %{"type" => "string"}
          }
        ],
        "responses" => %{
          "201" => %{
            "description" => "User created successfully",
            "content" => %{
              "application/json" => %{
                "schema" => %{"$ref" => "#/components/schemas/User"}
              }
            }
          },
          "400" => %{
            "description" => "Bad request"
          }
        },
        "security" => [
          %{"bearerAuth" => []}
        ],
        "requestBody" => %{
          "description" => "User data",
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{"$ref" => "#/components/schemas/CreateUserRequest"}
            }
          }
        }
      }

      operation = Operation.parse(input)

      assert operation.method == "post"
      assert operation.id == "createUser"
      assert operation.summary == "Create a new user"
      assert operation.description == "Creates a new user account in the system"
      assert operation.tags == ["users", "authentication"]
      assert length(operation.parameters) == 1
      assert Map.has_key?(operation.responses, "201")
      assert Map.has_key?(operation.responses, "400")
      assert operation.security == [%{"bearerAuth" => []}]
      assert operation.request_body != nil
      assert operation.request_body["description"] == "User data"
    end

    test "handles empty arrays and maps" do
      input = %{
        "method" => "get",
        "tags" => [],
        "parameters" => [],
        "responses" => %{},
        "security" => %{}
      }

      operation = Operation.parse(input)

      assert operation.method == "get"
      assert operation.tags == []
      assert operation.parameters == []
      assert operation.responses == %{}
      assert operation.security == %{}
    end

    test "handles nil values gracefully" do
      input = %{
        "method" => "get",
        "operationId" => nil,
        "summary" => nil,
        "description" => nil,
        "tags" => nil,
        "parameters" => nil,
        "responses" => nil,
        "security" => nil,
        "requestBody" => nil
      }

      operation = Operation.parse(input)

      assert operation.method == "get"
      assert operation.id == nil
      assert operation.summary == nil
      assert operation.description == nil
      assert operation.tags == []
      assert operation.parameters == []
      assert operation.responses == %{}
      assert operation.security == %{}
      assert operation.request_body == nil
    end

    test "parses parameters into Hydra.Spec.Parameter structs" do
      input = %{
        "method" => "get",
        "parameters" => [
          %{
            "name" => "limit",
            "in" => "query",
            "required" => false,
            "schema" => %{"type" => "integer", "minimum" => 1, "maximum" => 100}
          },
          %{
            "name" => "offset",
            "in" => "query",
            "required" => false,
            "schema" => %{"type" => "integer", "minimum" => 0}
          }
        ]
      }

      operation = Operation.parse(input)

      assert length(operation.parameters) == 2
      assert Enum.all?(operation.parameters, &is_struct(&1, Hydra.Spec.Parameter))

      limit_param = Enum.find(operation.parameters, &(&1.name == "limit"))
      assert limit_param != nil
      assert limit_param.in == "query"
      assert limit_param.required == false

      offset_param = Enum.find(operation.parameters, &(&1.name == "offset"))
      assert offset_param != nil
      assert offset_param.in == "query"
      assert offset_param.required == false
    end

    test "parses responses into Hydra.Spec.Response structs" do
      input = %{
        "method" => "get",
        "responses" => %{
          "200" => %{
            "description" => "Success",
            "content" => %{
              "application/json" => %{
                "schema" => %{"type" => "object"}
              }
            }
          },
          "404" => %{
            "description" => "Not found"
          },
          "500" => %{
            "description" => "Internal server error",
            "headers" => %{
              "X-Request-ID" => %{
                "schema" => %{"type" => "string"}
              }
            }
          }
        }
      }

      operation = Operation.parse(input)

      assert Map.has_key?(operation.responses, "200")
      assert Map.has_key?(operation.responses, "404")
      assert Map.has_key?(operation.responses, "500")

      success_response = operation.responses["200"]
      assert is_struct(success_response, Hydra.Spec.Response)
      assert success_response.description == "Success"
      assert Map.has_key?(success_response.content, "application/json")

      not_found_response = operation.responses["404"]
      assert is_struct(not_found_response, Hydra.Spec.Response)
      assert not_found_response.description == "Not found"

      error_response = operation.responses["500"]
      assert is_struct(error_response, Hydra.Spec.Response)
      assert error_response.description == "Internal server error"
      assert Map.has_key?(error_response.headers, "X-Request-ID")
    end

    test "handles single tag" do
      input = %{
        "method" => "get",
        "tags" => ["users"]
      }

      operation = Operation.parse(input)

      assert operation.tags == ["users"]
    end

    test "handles multiple tags" do
      input = %{
        "method" => "get",
        "tags" => ["users", "admin", "authentication"]
      }

      operation = Operation.parse(input)

      assert operation.tags == ["users", "admin", "authentication"]
    end

    test "preserves request body as raw map" do
      request_body = %{
        "description" => "User data to create",
        "required" => true,
        "content" => %{
          "application/json" => %{
            "schema" => %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string"},
                "email" => %{"type" => "string", "format" => "email"}
              },
              "required" => ["name", "email"]
            }
          },
          "application/xml" => %{
            "schema" => %{"$ref" => "#/components/schemas/User"}
          }
        }
      }

      input = %{
        "method" => "post",
        "requestBody" => request_body
      }

      operation = Operation.parse(input)

      assert operation.request_body == request_body
    end

    test "preserves security configuration as raw data" do
      security = [
        %{"apiKeyAuth" => []},
        %{"bearerAuth" => [], "oauth2" => ["read", "write"]}
      ]

      input = %{
        "method" => "get",
        "security" => security
      }

      operation = Operation.parse(input)

      assert operation.security == security
    end
  end
end
