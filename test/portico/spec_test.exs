defmodule Portico.SpecTest do
  use ExUnit.Case, async: true

  alias Portico.Spec

  describe "parse/1" do
    test "parses a minimal OpenAPI spec" do
      json = %{
        "openapi" => "3.0.0",
        "info" => %{
          "title" => "Test API",
          "version" => "1.0.0"
        },
        "paths" => %{}
      }

      spec = Spec.parse(json)

      assert spec.version == "3.0.0"
      assert spec.info == %{"title" => "Test API", "version" => "1.0.0"}
      assert spec.paths == []
      assert spec.servers == nil
      assert spec.components == nil
      assert spec.security == nil
      assert spec.tags == nil
      assert spec.external_docs == nil
    end

    test "parses a complete OpenAPI spec with all fields" do
      json = %{
        "openapi" => "3.0.0",
        "info" => %{
          "title" => "Test API",
          "version" => "1.0.0"
        },
        "paths" => %{
          "/users" => %{
            "get" => %{
              "summary" => "List users",
              "tags" => ["users"]
            }
          }
        },
        "servers" => [
          %{"url" => "https://api.example.com"}
        ],
        "components" => %{
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "name" => %{"type" => "string"}
              }
            }
          }
        },
        "security" => [
          %{"bearerAuth" => []}
        ],
        "tags" => [
          %{"name" => "users", "description" => "User operations"}
        ],
        "externalDocs" => %{
          "description" => "Find more info here",
          "url" => "https://example.com"
        }
      }

      spec = Spec.parse(json)

      assert spec.version == "3.0.0"
      assert spec.info == %{"title" => "Test API", "version" => "1.0.0"}
      assert length(spec.paths) == 1
      assert spec.servers == [%{"url" => "https://api.example.com"}]

      assert spec.components == %{
               "schemas" => %{
                 "User" => %{
                   "type" => "object",
                   "properties" => %{
                     "id" => %{"type" => "integer"},
                     "name" => %{"type" => "string"}
                   }
                 }
               }
             }

      assert spec.security == [%{"bearerAuth" => []}]
      assert spec.tags == [%{"name" => "users", "description" => "User operations"}]

      assert spec.external_docs == %{
               "description" => "Find more info here",
               "url" => "https://example.com"
             }
    end

    test "handles nil/empty values gracefully" do
      json = %{
        "openapi" => "3.0.0",
        "info" => %{},
        "paths" => %{}
      }

      spec = Spec.parse(json)

      assert spec.version == "3.0.0"
      assert spec.info == %{}
      assert spec.paths == []
      assert spec.servers == nil
      assert spec.components == nil
      assert spec.security == nil
      assert spec.tags == nil
      assert spec.external_docs == nil
    end

    test "parses paths into Portico.Spec.Path structs" do
      json = %{
        "openapi" => "3.0.0",
        "info" => %{},
        "paths" => %{
          "/users" => %{
            "get" => %{
              "summary" => "List users"
            }
          },
          "/users/{id}" => %{
            "get" => %{
              "summary" => "Get user"
            },
            "parameters" => [
              %{
                "name" => "id",
                "in" => "path",
                "required" => true,
                "schema" => %{"type" => "integer"}
              }
            ]
          }
        }
      }

      spec = Spec.parse(json)

      assert length(spec.paths) == 2
      assert Enum.all?(spec.paths, &is_struct(&1, Portico.Spec.Path))

      paths_by_path = Enum.into(spec.paths, %{}, fn path -> {path.path, path} end)
      assert Map.has_key?(paths_by_path, "/users")
      assert Map.has_key?(paths_by_path, "/users/{id}")

      users_path = paths_by_path["/users"]
      assert length(users_path.operations) == 1
      assert length(users_path.parameters) == 0

      user_id_path = paths_by_path["/users/{id}"]
      assert length(user_id_path.operations) == 1
      assert length(user_id_path.parameters) == 1
    end

    test "normalizes parameter names with special characters" do
      json = %{
        "openapi" => "3.0.0",
        "info" => %{},
        "paths" => %{
          "/test" => %{
            "get" => %{
              "summary" => "Test special parameter names",
              "parameters" => [
                %{
                  "name" => "@id",
                  "in" => "query",
                  "required" => true,
                  "schema" => %{"type" => "string"}
                },
                %{
                  "name" => "$top",
                  "in" => "query",
                  "required" => false,
                  "schema" => %{"type" => "integer"}
                },
                %{
                  "name" => "@odata.id",
                  "in" => "query",
                  "required" => false,
                  "schema" => %{"type" => "string"}
                }
              ]
            }
          }
        }
      }

      spec = Spec.parse(json)
      path = Enum.find(spec.paths, &(&1.path == "/test"))
      operation = List.first(path.operations)
      
      param_names = Enum.map(operation.parameters, & &1.internal_name)
      
      # @ should be replaced with "at_"
      assert "at_id" in param_names
      # $ should be replaced with "dollar_"
      assert "dollar_top" in param_names
      # Complex case with both @ and .
      assert "at_odata_id" in param_names
    end
  end
end
