defmodule Hydra.Spec.ResolverTest do
  use ExUnit.Case
  alias Hydra.Spec.Resolver

  describe "resolve/1" do
    test "resolves basic $ref in parameters" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/Query"}]
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{
              "in" => "query",
              "name" => "q",
              "schema" => %{"type" => "string"}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_param = %{
        "in" => "query",
        "name" => "q",
        "schema" => %{"type" => "string"}
      }

      assert resolved["paths"]["/users"]["parameters"] == [expected_param]
      assert resolved["components"] == spec["components"]
    end

    test "resolves multiple $refs in the same array" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [
              %{"$ref" => "#/components/parameters/Query"},
              %{"$ref" => "#/components/parameters/Limit"}
            ]
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{"in" => "query", "name" => "q"},
            "Limit" => %{"in" => "query", "name" => "limit"}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_params = [
        %{"in" => "query", "name" => "q"},
        %{"in" => "query", "name" => "limit"}
      ]

      assert resolved["paths"]["/users"]["parameters"] == expected_params
    end

    test "resolves nested $refs" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "requestBody" => %{"$ref" => "#/components/requestBodies/User"}
          }
        },
        "components" => %{
          "requestBodies" => %{
            "User" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/User"}
                }
              }
            }
          },
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{"name" => %{"type" => "string"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}}
      }

      assert resolved["paths"]["/users"]["requestBody"]["content"]["application/json"]["schema"] ==
               expected_schema
    end

    test "resolves $refs in deeply nested structures" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/UserList"}
                    }
                  }
                }
              }
            }
          }
        },
        "components" => %{
          "schemas" => %{
            "UserList" => %{
              "type" => "array",
              "items" => %{"$ref" => "#/components/schemas/User"}
            },
            "User" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_user = %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "integer"}}
      }

      user_list_schema =
        resolved["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert user_list_schema["type"] == "array"
      assert user_list_schema["items"] == expected_user
    end

    test "handles mixed $refs and regular objects" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [
              %{"$ref" => "#/components/parameters/Query"},
              %{
                "in" => "query",
                "name" => "inline_param",
                "schema" => %{"type" => "boolean"}
              }
            ]
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{"in" => "query", "name" => "q"}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_params = [
        %{"in" => "query", "name" => "q"},
        %{
          "in" => "query",
          "name" => "inline_param",
          "schema" => %{"type" => "boolean"}
        }
      ]

      assert resolved["paths"]["/users"]["parameters"] == expected_params
    end

    test "preserves non-$ref content unchanged" do
      spec = %{
        "openapi" => "3.0.0",
        "info" => %{
          "title" => "Test API",
          "version" => "1.0.0"
        },
        "paths" => %{
          "/test" => %{
            "get" => %{
              "summary" => "Test endpoint",
              "responses" => %{
                "200" => %{"description" => "OK"}
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      assert resolved == spec
    end

    test "handles empty maps and arrays" do
      spec = %{
        "paths" => %{},
        "components" => %{
          "parameters" => %{},
          "schemas" => %{}
        },
        "tags" => []
      }

      resolved = Resolver.resolve(spec)

      assert resolved == spec
    end
  end

  describe "error handling" do
    test "raises error for missing reference" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/NonExistent"}]
          }
        },
        "components" => %{
          "parameters" => %{}
        }
      }

      assert_raise RuntimeError, ~r/Reference not found.*NonExistent/, fn ->
        Resolver.resolve(spec)
      end
    end

    test "raises error for circular references" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "A" => %{"$ref" => "#/components/schemas/B"},
            "B" => %{"$ref" => "#/components/schemas/A"}
          }
        },
        "paths" => %{
          "/test" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/A"}
                    }
                  }
                }
              }
            }
          }
        }
      }

      assert_raise RuntimeError, ~r/Circular reference detected/, fn ->
        Resolver.resolve(spec)
      end
    end

    test "raises error for unsupported reference format" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "external.yaml#/components/parameters/Query"}]
          }
        }
      }

      assert_raise RuntimeError, ~r/Unsupported reference format/, fn ->
        Resolver.resolve(spec)
      end
    end

    test "raises error for malformed JSON pointer" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/nonexistent/Query"}]
          }
        },
        "components" => %{
          "parameters" => %{}
        }
      }

      assert_raise RuntimeError, ~r/Reference not found/, fn ->
        Resolver.resolve(spec)
      end
    end
  end

  describe "JSON Pointer edge cases" do
    test "handles escaped characters in JSON Pointer" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/weird~1name~0param"}]
          }
        },
        "components" => %{
          "parameters" => %{
            "weird/name~param" => %{
              "in" => "query",
              "name" => "escaped"
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_param = %{
        "in" => "query",
        "name" => "escaped"
      }

      assert resolved["paths"]["/users"]["parameters"] == [expected_param]
    end

    test "handles deep nesting in JSON Pointer" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "responses" => %{
              "200" => %{"$ref" => "#/very/deep/nested/structure"}
            }
          }
        },
        "very" => %{
          "deep" => %{
            "nested" => %{
              "structure" => %{
                "description" => "Deep response"
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      expected_response = %{
        "description" => "Deep response"
      }

      assert resolved["paths"]["/users"]["responses"]["200"] == expected_response
    end
  end

  describe "integration with realistic OpenAPI structures" do
    test "resolves complex OpenAPI spec with multiple reference types" do
      spec = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0.0"},
        "paths" => %{
          "/users" => %{
            "parameters" => [
              %{"$ref" => "#/components/parameters/Query"},
              %{"$ref" => "#/components/parameters/Limit"}
            ],
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/UserList"}
                    }
                  }
                }
              }
            },
            "post" => %{
              "requestBody" => %{"$ref" => "#/components/requestBodies/CreateUser"},
              "responses" => %{
                "201" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/User"}
                    }
                  }
                }
              }
            }
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{"in" => "query", "name" => "q"},
            "Limit" => %{"in" => "query", "name" => "limit"}
          },
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "name" => %{"type" => "string"}
              }
            },
            "UserList" => %{
              "type" => "array",
              "items" => %{"$ref" => "#/components/schemas/User"}
            }
          },
          "requestBodies" => %{
            "CreateUser" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/User"}
                }
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      # Check that all references are resolved
      user_schema = %{
        "type" => "object",
        "properties" => %{
          "id" => %{"type" => "integer"},
          "name" => %{"type" => "string"}
        }
      }

      # Parameters should be resolved
      assert resolved["paths"]["/users"]["parameters"] == [
               %{"in" => "query", "name" => "q"},
               %{"in" => "query", "name" => "limit"}
             ]

      # Response schema should be resolved
      get_response_schema =
        resolved["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert get_response_schema["type"] == "array"
      assert get_response_schema["items"] == user_schema

      # Request body schema should be resolved
      post_request_schema =
        resolved["paths"]["/users"]["post"]["requestBody"]["content"]["application/json"][
          "schema"
        ]

      assert post_request_schema == user_schema

      # Post response schema should be resolved
      post_response_schema =
        resolved["paths"]["/users"]["post"]["responses"]["201"]["content"]["application/json"][
          "schema"
        ]

      assert post_response_schema == user_schema

      # Components should have refs resolved too
      assert resolved["components"]["requestBodies"]["CreateUser"]["content"]["application/json"][
               "schema"
             ] == user_schema

      assert resolved["components"]["schemas"]["UserList"]["items"] == user_schema
    end
  end

  describe "integration with file parsing" do
    test "resolves $refs in JSON files" do
      spec = Hydra.parse!("test/fixtures/test_spec_with_refs.json")

      # Verify that references were resolved during parsing
      users_path = Enum.find(spec.paths, fn path -> path.path == "/users" end)
      assert users_path != nil

      assert users_path.parameters != nil
      assert length(users_path.parameters) == 1

      param = hd(users_path.parameters)
      assert param.name == "q"
      assert param.in == "query"
    end

    test "resolves $refs in YAML files" do
      spec = Hydra.parse!("test/fixtures/test_spec_with_refs.yaml")

      # Verify that references were resolved during parsing
      users_path = Enum.find(spec.paths, fn path -> path.path == "/users" end)
      assert users_path != nil

      assert users_path.parameters != nil
      assert length(users_path.parameters) == 1

      param = hd(users_path.parameters)
      assert param.name == "q"
      assert param.in == "query"
    end

    test "JSON and YAML produce equivalent resolved specs" do
      json_spec = Hydra.parse!("test/fixtures/test_spec_with_refs.json")
      yaml_spec = Hydra.parse!("test/fixtures/test_spec_with_refs.yaml")

      # Both should have the same resolved parameter
      json_path = Enum.find(json_spec.paths, fn path -> path.path == "/users" end)
      yaml_path = Enum.find(yaml_spec.paths, fn path -> path.path == "/users" end)

      json_param = hd(json_path.parameters)
      yaml_param = hd(yaml_path.parameters)

      assert json_param.name == yaml_param.name
      assert json_param.in == yaml_param.in
      assert json_param.internal_name == yaml_param.internal_name
    end
  end
end
