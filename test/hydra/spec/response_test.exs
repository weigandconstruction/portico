defmodule Hydra.Spec.ResponseTest do
  use ExUnit.Case, async: true

  alias Hydra.Spec.Response

  describe "parse/1" do
    test "parses a minimal response with only description" do
      input = %{
        "description" => "Success"
      }

      response = Response.parse(input)

      assert response.description == "Success"
      assert response.headers == %{}
      assert response.content == %{}
      assert response.links == %{}
    end

    test "parses a complete response with all fields" do
      input = %{
        "description" => "User created successfully",
        "headers" => %{
          "X-Request-ID" => %{
            "description" => "Unique request identifier",
            "schema" => %{"type" => "string"}
          },
          "X-Rate-Limit" => %{
            "description" => "Rate limit information",
            "schema" => %{"type" => "integer"}
          }
        },
        "content" => %{
          "application/json" => %{
            "schema" => %{
              "$ref" => "#/components/schemas/User"
            },
            "examples" => %{
              "user_example" => %{
                "summary" => "Example user",
                "value" => %{
                  "id" => 123,
                  "name" => "John Doe",
                  "email" => "john@example.com"
                }
              }
            }
          },
          "application/xml" => %{
            "schema" => %{
              "$ref" => "#/components/schemas/User"
            }
          }
        },
        "links" => %{
          "GetUserById" => %{
            "operationId" => "getUser",
            "parameters" => %{
              "userId" => "$response.body#/id"
            }
          },
          "UpdateUser" => %{
            "operationId" => "updateUser",
            "parameters" => %{
              "userId" => "$response.body#/id"
            }
          }
        }
      }

      response = Response.parse(input)

      assert response.description == "User created successfully"
      
      # Check headers
      assert Map.has_key?(response.headers, "X-Request-ID")
      assert Map.has_key?(response.headers, "X-Rate-Limit")
      assert response.headers["X-Request-ID"]["description"] == "Unique request identifier"
      assert response.headers["X-Rate-Limit"]["schema"]["type"] == "integer"
      
      # Check content
      assert Map.has_key?(response.content, "application/json")
      assert Map.has_key?(response.content, "application/xml")
      assert response.content["application/json"]["schema"]["$ref"] == "#/components/schemas/User"
      assert Map.has_key?(response.content["application/json"], "examples")
      
      # Check links
      assert Map.has_key?(response.links, "GetUserById")
      assert Map.has_key?(response.links, "UpdateUser")
      assert response.links["GetUserById"]["operationId"] == "getUser"
    end

    test "handles empty maps and defaults" do
      input = %{
        "description" => "Empty response"
      }

      response = Response.parse(input)

      assert response.description == "Empty response"
      assert response.headers == %{}
      assert response.content == %{}
      assert response.links == %{}
    end

    test "handles nil description" do
      input = %{
        "description" => nil
      }

      response = Response.parse(input)

      assert response.description == nil
      assert response.headers == %{}
      assert response.content == %{}
      assert response.links == %{}
    end

    test "handles missing optional fields" do
      input = %{
        "description" => "Response without optional fields"
      }

      response = Response.parse(input)

      assert response.description == "Response without optional fields"
      assert response.headers == %{}
      assert response.content == %{}
      assert response.links == %{}
    end

    test "preserves complex header schemas" do
      headers = %{
        "Authorization" => %{
          "description" => "Bearer token",
          "schema" => %{
            "type" => "string",
            "pattern" => "^Bearer [A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_.+/=]*$"
          }
        },
        "Cache-Control" => %{
          "description" => "Cache control directives",
          "schema" => %{
            "type" => "string",
            "enum" => ["no-cache", "no-store", "must-revalidate"]
          }
        }
      }

      input = %{
        "description" => "Response with complex headers",
        "headers" => headers
      }

      response = Response.parse(input)

      assert response.headers == headers
      assert response.headers["Authorization"]["schema"]["pattern"] == "^Bearer [A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_.+/=]*$"
      assert response.headers["Cache-Control"]["schema"]["enum"] == ["no-cache", "no-store", "must-revalidate"]
    end

    test "preserves complex content with multiple media types" do
      content = %{
        "application/json" => %{
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "users" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components/schemas/User"}
              },
              "pagination" => %{
                "type" => "object",
                "properties" => %{
                  "page" => %{"type" => "integer"},
                  "total" => %{"type" => "integer"}
                }
              }
            }
          },
          "examples" => %{
            "users_list" => %{
              "value" => %{
                "users" => [
                  %{"id" => 1, "name" => "Alice"},
                  %{"id" => 2, "name" => "Bob"}
                ],
                "pagination" => %{"page" => 1, "total" => 2}
              }
            }
          }
        },
        "application/xml" => %{
          "schema" => %{
            "type" => "string",
            "xml" => %{
              "name" => "users"
            }
          }
        },
        "text/csv" => %{
          "schema" => %{
            "type" => "string"
          },
          "example" => "id,name\n1,Alice\n2,Bob"
        }
      }

      input = %{
        "description" => "Multi-format response",
        "content" => content
      }

      response = Response.parse(input)

      assert response.content == content
      assert Map.has_key?(response.content, "application/json")
      assert Map.has_key?(response.content, "application/xml")
      assert Map.has_key?(response.content, "text/csv")
      assert response.content["text/csv"]["example"] == "id,name\n1,Alice\n2,Bob"
    end

    test "preserves complex links with runtime expressions" do
      links = %{
        "GetUserByName" => %{
          "operationRef" => "#/paths/~1users~1{username}/get",
          "parameters" => %{
            "username" => "$response.body#/username"
          },
          "description" => "Get user by username from the response"
        },
        "GetUserPosts" => %{
          "operationId" => "getUserPosts",
          "parameters" => %{
            "userId" => "$response.body#/id",
            "limit" => 10
          },
          "requestBody" => %{
            "created_since" => "$response.body#/created_at"
          }
        },
        "DeleteUser" => %{
          "operationId" => "deleteUser",
          "parameters" => %{
            "userId" => "$response.body#/id"
          },
          "server" => %{
            "url" => "https://admin.example.com"
          }
        }
      }

      input = %{
        "description" => "Response with complex links",
        "links" => links
      }

      response = Response.parse(input)

      assert response.links == links
      assert response.links["GetUserByName"]["operationRef"] == "#/paths/~1users~1{username}/get"
      assert response.links["GetUserPosts"]["parameters"]["limit"] == 10
      assert response.links["DeleteUser"]["server"]["url"] == "https://admin.example.com"
    end

    test "handles response with only headers" do
      input = %{
        "description" => "Headers only response",
        "headers" => %{
          "Location" => %{
            "description" => "URL of the created resource",
            "schema" => %{"type" => "string", "format" => "uri"}
          }
        }
      }

      response = Response.parse(input)

      assert response.description == "Headers only response"
      assert Map.has_key?(response.headers, "Location")
      assert response.content == %{}
      assert response.links == %{}
    end

    test "handles response with only content" do
      input = %{
        "description" => "Content only response",
        "content" => %{
          "application/json" => %{
            "schema" => %{"type" => "string"}
          }
        }
      }

      response = Response.parse(input)

      assert response.description == "Content only response"
      assert response.headers == %{}
      assert Map.has_key?(response.content, "application/json")
      assert response.links == %{}
    end

    test "handles response with only links" do
      input = %{
        "description" => "Links only response",
        "links" => %{
          "NextPage" => %{
            "operationId" => "getUsers",
            "parameters" => %{
              "page" => "$response.body#/next_page"
            }
          }
        }
      }

      response = Response.parse(input)

      assert response.description == "Links only response"
      assert response.headers == %{}
      assert response.content == %{}
      assert Map.has_key?(response.links, "NextPage")
    end
  end
end