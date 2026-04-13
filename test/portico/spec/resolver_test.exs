defmodule Portico.Spec.ResolverTest do
  use ExUnit.Case
  alias Portico.Spec.Resolver

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

    test "resolves nested $refs, preserving schema ref as metadata" do
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

      # The requestBody ref (non-schema) is fully resolved — no $ref survives
      # on the outer requestBody wrapper.
      resolved_body = resolved["paths"]["/users"]["requestBody"]
      refute Map.has_key?(resolved_body, "$ref")

      # The schema ref inside it IS preserved, alongside the inlined content.
      schema = resolved_body["content"]["application/json"]["schema"]
      assert schema["$ref"] == "#/components/schemas/User"
      assert schema["type"] == "object"
      assert schema["properties"] == %{"name" => %{"type" => "string"}}
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

      user_list_schema =
        resolved["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      # UserList is a schema ref — outer shape is preserved with its $ref tag
      # alongside the inlined array content.
      assert user_list_schema["$ref"] == "#/components/schemas/UserList"
      assert user_list_schema["type"] == "array"

      # items is a ref to User — that ref is preserved too, with User's
      # content inlined.
      items = user_list_schema["items"]
      assert items["$ref"] == "#/components/schemas/User"
      assert items["type"] == "object"
      assert items["properties"] == %{"id" => %{"type" => "integer"}}
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

    test "handles simple circular references (A → B → A)" do
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

      # Should not raise an error, but return the spec with circular refs intact
      result = Resolver.resolve(spec)

      # With circular references, the resolver prevents infinite recursion
      # The exact resolution depends on traversal order, but both should have $ref
      assert Map.has_key?(result["components"]["schemas"]["A"], "$ref")
      assert Map.has_key?(result["components"]["schemas"]["B"], "$ref")

      # The important thing is that we don't have infinite expansion
      assert is_map(result["components"]["schemas"]["A"])
      assert is_map(result["components"]["schemas"]["B"])

      # The schema reference should also be preserved
      schema_ref =
        result["paths"]["/test"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert Map.has_key?(schema_ref, "$ref")
      assert schema_ref["$ref"] in ["#/components/schemas/A", "#/components/schemas/B"]
    end

    test "handles self-referential schemas" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "TreeNode" => %{
              "type" => "object",
              "properties" => %{
                "value" => %{"type" => "string"},
                "children" => %{
                  "type" => "array",
                  "items" => %{"$ref" => "#/components/schemas/TreeNode"}
                }
              }
            }
          }
        }
      }

      result = Resolver.resolve(spec)

      # The TreeNode should prevent infinite expansion
      tree_node = result["components"]["schemas"]["TreeNode"]
      assert tree_node["type"] == "object"
      assert tree_node["properties"]["value"]["type"] == "string"

      # The circular reference should be handled gracefully
      children_items = tree_node["properties"]["children"]["items"]
      assert is_map(children_items)
      # May contain a $ref or be expanded, but should not cause infinite recursion
    end

    test "handles longer circular reference chains (A → B → C → A)" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "A" => %{"$ref" => "#/components/schemas/B"},
            "B" => %{"$ref" => "#/components/schemas/C"},
            "C" => %{
              "type" => "object",
              "properties" => %{
                "next" => %{"$ref" => "#/components/schemas/A"}
              }
            }
          }
        }
      }

      result = Resolver.resolve(spec)

      # Should not crash due to infinite recursion
      # The exact resolution depends on caching and traversal order
      assert is_map(result["components"]["schemas"]["A"])
      assert is_map(result["components"]["schemas"]["B"])
      assert is_map(result["components"]["schemas"]["C"])

      # At least one should maintain object structure
      schemas = [
        result["components"]["schemas"]["A"],
        result["components"]["schemas"]["B"],
        result["components"]["schemas"]["C"]
      ]

      assert Enum.any?(schemas, &(&1["type"] == "object"))
    end

    test "handles circular references with mixed content" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string"},
                "bestFriend" => %{"$ref" => "#/components/schemas/User"},
                "friends" => %{
                  "type" => "array",
                  "items" => %{"$ref" => "#/components/schemas/User"}
                }
              }
            }
          }
        }
      }

      result = Resolver.resolve(spec)

      user = result["components"]["schemas"]["User"]
      assert user["type"] == "object"
      assert user["properties"]["name"]["type"] == "string"

      # Should not cause infinite recursion
      assert is_map(user["properties"]["bestFriend"])
      assert is_map(user["properties"]["friends"]["items"])

      # Structure should be preserved
      assert user["properties"]["friends"]["type"] == "array"
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

      user_properties = %{
        "id" => %{"type" => "integer"},
        "name" => %{"type" => "string"}
      }

      # Parameter refs (non-schema) are fully inlined — no $ref survives.
      assert resolved["paths"]["/users"]["parameters"] == [
               %{"in" => "query", "name" => "q"},
               %{"in" => "query", "name" => "limit"}
             ]

      # GET response: schema is `array of User`. The array wrapper stays,
      # items carries the User ref tag + inlined content.
      get_response_schema =
        resolved["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert get_response_schema["$ref"] == "#/components/schemas/UserList"
      assert get_response_schema["type"] == "array"
      assert get_response_schema["items"]["$ref"] == "#/components/schemas/User"
      assert get_response_schema["items"]["type"] == "object"
      assert get_response_schema["items"]["properties"] == user_properties

      # POST request body: requestBody ref is fully inlined, the schema ref
      # inside it is preserved.
      post_request_schema =
        resolved["paths"]["/users"]["post"]["requestBody"]["content"]["application/json"][
          "schema"
        ]

      assert post_request_schema["$ref"] == "#/components/schemas/User"
      assert post_request_schema["type"] == "object"
      assert post_request_schema["properties"] == user_properties

      # POST response: direct schema ref preserved.
      post_response_schema =
        resolved["paths"]["/users"]["post"]["responses"]["201"]["content"]["application/json"][
          "schema"
        ]

      assert post_response_schema["$ref"] == "#/components/schemas/User"
      assert post_response_schema["type"] == "object"

      # Components themselves are not refs, so they don't pick up $ref keys
      # at their top level — but nested schema refs inside them do.
      create_user_schema =
        resolved["components"]["requestBodies"]["CreateUser"]["content"]["application/json"][
          "schema"
        ]

      assert create_user_schema["$ref"] == "#/components/schemas/User"

      user_list_items = resolved["components"]["schemas"]["UserList"]["items"]
      assert user_list_items["$ref"] == "#/components/schemas/User"
      assert user_list_items["properties"] == user_properties

      # The target schemas themselves (not accessed via $ref at this level)
      # have no $ref key on their top-level entry.
      refute Map.has_key?(resolved["components"]["schemas"]["User"], "$ref")
      refute Map.has_key?(resolved["components"]["schemas"]["UserList"], "$ref")
    end
  end

  describe "integration with file parsing" do
    test "resolves $refs in JSON files" do
      spec = Portico.parse!("test/fixtures/test_spec_with_refs.json")

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
      spec = Portico.parse!("test/fixtures/test_spec_with_refs.yaml")

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
      json_spec = Portico.parse!("test/fixtures/test_spec_with_refs.json")
      yaml_spec = Portico.parse!("test/fixtures/test_spec_with_refs.yaml")

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

  # The schema-ref contract is the load-bearing behavior for model generation.
  # These tests pin it down precisely.
  describe "schema ref preservation" do
    test "direct schema ref is tagged with $ref and inlined with content" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
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
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      schema =
        resolved["paths"]["/users"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert schema["$ref"] == "#/components/schemas/User"
      assert schema["type"] == "object"
      assert schema["properties"] == %{"id" => %{"type" => "integer"}}
    end

    test "non-schema refs (parameters) are fully inlined with no $ref residue" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/Query"}]
          }
        },
        "components" => %{
          "parameters" => %{
            "Query" => %{"in" => "query", "name" => "q"}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      [param] = resolved["paths"]["/users"]["parameters"]
      assert param == %{"in" => "query", "name" => "q"}
      refute Map.has_key?(param, "$ref")
    end

    test "non-schema refs (responses) are fully inlined with no $ref residue" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "get" => %{"responses" => %{"200" => %{"$ref" => "#/components/responses/Ok"}}}
          }
        },
        "components" => %{
          "responses" => %{
            "Ok" => %{"description" => "Successful response"}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      response = resolved["paths"]["/users"]["get"]["responses"]["200"]
      assert response == %{"description" => "Successful response"}
      refute Map.has_key?(response, "$ref")
    end

    test "non-schema refs (requestBodies) are fully inlined but inner schema ref is tagged" do
      spec = %{
        "paths" => %{
          "/users" => %{
            "post" => %{"requestBody" => %{"$ref" => "#/components/requestBodies/User"}}
          }
        },
        "components" => %{
          "requestBodies" => %{
            "User" => %{
              "required" => true,
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/User"}
                }
              }
            }
          },
          "schemas" => %{
            "User" => %{"type" => "object", "properties" => %{"id" => %{"type" => "integer"}}}
          }
        }
      }

      resolved = Resolver.resolve(spec)
      request_body = resolved["paths"]["/users"]["post"]["requestBody"]

      # requestBody ref — fully absorbed
      refute Map.has_key?(request_body, "$ref")
      assert request_body["required"] == true

      # schema ref inside — tagged
      schema = request_body["content"]["application/json"]["schema"]
      assert schema["$ref"] == "#/components/schemas/User"
      assert schema["type"] == "object"
    end

    test "schema ref inside a non-schema ref still gets preserved" do
      # A parameter whose schema is itself a ref — parameter gets inlined,
      # but the schema ref inside the parameter must survive with its tag.
      spec = %{
        "paths" => %{
          "/users" => %{
            "parameters" => [%{"$ref" => "#/components/parameters/UserFilter"}]
          }
        },
        "components" => %{
          "parameters" => %{
            "UserFilter" => %{
              "in" => "query",
              "name" => "filter",
              "schema" => %{"$ref" => "#/components/schemas/UserFilter"}
            }
          },
          "schemas" => %{
            "UserFilter" => %{
              "type" => "object",
              "properties" => %{"status" => %{"type" => "string"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      [param] = resolved["paths"]["/users"]["parameters"]

      # parameter ref is gone
      refute Map.has_key?(param, "$ref")
      assert param["in"] == "query"
      assert param["name"] == "filter"

      # but the schema ref inside the parameter stays tagged
      assert param["schema"]["$ref"] == "#/components/schemas/UserFilter"
      assert param["schema"]["type"] == "object"
      assert param["schema"]["properties"]["status"] == %{"type" => "string"}
    end

    test "nested schema ref (object property pointing at another schema) is preserved" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "Pet" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "category" => %{"$ref" => "#/components/schemas/Category"}
              }
            },
            "Category" => %{
              "type" => "object",
              "properties" => %{"name" => %{"type" => "string"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      # Pet's top-level entry isn't a ref — no $ref key
      pet = resolved["components"]["schemas"]["Pet"]
      refute Map.has_key?(pet, "$ref")
      assert pet["type"] == "object"

      # Pet.properties.category IS a ref — tagged + content inlined
      category = pet["properties"]["category"]
      assert category["$ref"] == "#/components/schemas/Category"
      assert category["type"] == "object"
      assert category["properties"]["name"] == %{"type" => "string"}
    end

    test "schema ref inside array items is preserved" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "PetList" => %{
              "type" => "array",
              "items" => %{"$ref" => "#/components/schemas/Pet"}
            },
            "Pet" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      items = resolved["components"]["schemas"]["PetList"]["items"]

      assert items["$ref"] == "#/components/schemas/Pet"
      assert items["type"] == "object"
      assert items["properties"]["id"] == %{"type" => "integer"}
    end

    test "multiple refs to the same schema produce identical tagged maps" do
      spec = %{
        "paths" => %{
          "/a" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/User"}
                    }
                  }
                }
              }
            }
          },
          "/b" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
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
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      a =
        resolved["paths"]["/a"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      b =
        resolved["paths"]["/b"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert a == b
      assert a["$ref"] == "#/components/schemas/User"
    end

    test "schema ref resolves with tag even when target itself contains nested refs" do
      spec = %{
        "paths" => %{
          "/pet" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/Pet"}
                    }
                  }
                }
              }
            }
          }
        },
        "components" => %{
          "schemas" => %{
            "Pet" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "owner" => %{"$ref" => "#/components/schemas/Owner"}
              }
            },
            "Owner" => %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string"},
                "address" => %{"$ref" => "#/components/schemas/Address"}
              }
            },
            "Address" => %{
              "type" => "object",
              "properties" => %{"street" => %{"type" => "string"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      pet =
        resolved["paths"]["/pet"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert pet["$ref"] == "#/components/schemas/Pet"
      # Owner preserved as a ref with content
      owner = pet["properties"]["owner"]
      assert owner["$ref"] == "#/components/schemas/Owner"
      # Address even deeper — still preserved
      address = owner["properties"]["address"]
      assert address["$ref"] == "#/components/schemas/Address"
      assert address["properties"]["street"] == %{"type" => "string"}
    end

    test "self-referential schema keeps its ref at the cycle-back point" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "TreeNode" => %{
              "type" => "object",
              "properties" => %{
                "value" => %{"type" => "string"},
                "children" => %{
                  "type" => "array",
                  "items" => %{"$ref" => "#/components/schemas/TreeNode"}
                }
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      tree = resolved["components"]["schemas"]["TreeNode"]

      # Top-level TreeNode not reached via a ref walk — no $ref at root
      refute Map.has_key?(tree, "$ref")
      assert tree["type"] == "object"

      # items is a ref back to TreeNode — regardless of whether the resolver
      # hit the cache, expanded one level, or bailed on the cycle, the $ref
      # pointer must be present so the generator can round-trip it.
      items = tree["properties"]["children"]["items"]
      assert items["$ref"] == "#/components/schemas/TreeNode"
    end

    test "direct circular schema refs (A → B → A) preserve $ref on both sides" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "A" => %{
              "type" => "object",
              "properties" => %{"b" => %{"$ref" => "#/components/schemas/B"}}
            },
            "B" => %{
              "type" => "object",
              "properties" => %{"a" => %{"$ref" => "#/components/schemas/A"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      a = resolved["components"]["schemas"]["A"]
      b = resolved["components"]["schemas"]["B"]

      refute Map.has_key?(a, "$ref")
      refute Map.has_key?(b, "$ref")

      assert a["properties"]["b"]["$ref"] == "#/components/schemas/B"
      assert b["properties"]["a"]["$ref"] == "#/components/schemas/A"
    end

    test "cached schema ref expansion reuses the tagged map" do
      # Same schema referenced twice — the second reference should hit the
      # cache and get an identical tagged result.
      spec = %{
        "components" => %{
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            },
            "Post" => %{
              "type" => "object",
              "properties" => %{
                "author" => %{"$ref" => "#/components/schemas/User"},
                "editor" => %{"$ref" => "#/components/schemas/User"}
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      post = resolved["components"]["schemas"]["Post"]

      author = post["properties"]["author"]
      editor = post["properties"]["editor"]

      assert author == editor
      assert author["$ref"] == "#/components/schemas/User"
      assert author["type"] == "object"
    end

    test "schema ref to a scalar schema (string, enum) is preserved" do
      # Schemas aren't always objects — sometimes they're named enums or
      # scalar aliases. The ref should still be preserved.
      spec = %{
        "components" => %{
          "schemas" => %{
            "Status" => %{
              "type" => "string",
              "enum" => ["active", "inactive"]
            },
            "User" => %{
              "type" => "object",
              "properties" => %{
                "status" => %{"$ref" => "#/components/schemas/Status"}
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      status = resolved["components"]["schemas"]["User"]["properties"]["status"]

      assert status["$ref"] == "#/components/schemas/Status"
      assert status["type"] == "string"
      assert status["enum"] == ["active", "inactive"]
    end

    test "root $ref to a component schema resolves into a tagged map" do
      # Unusual but legal: the top-level value is itself just {"$ref": ...}.
      spec = %{"$ref" => "#/components/schemas/User"}

      # This particular shape is not really a full OpenAPI spec, so we
      # include it inside a valid one.
      full = %{
        "paths" => %{"/x" => spec},
        "components" => %{
          "schemas" => %{
            "User" => %{"type" => "object", "properties" => %{}}
          }
        }
      }

      resolved = Resolver.resolve(full)

      assert resolved["paths"]["/x"]["$ref"] == "#/components/schemas/User"
      assert resolved["paths"]["/x"]["type"] == "object"
    end

    test "Spec.Schema.parse sees the preserved ref and populates :ref" do
      # End-to-end: the whole point of preservation is that schema parsing
      # picks it up. This test pins the wiring between Resolver and
      # Spec.Schema.parse.
      spec = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "T", "version" => "1"},
        "paths" => %{
          "/x" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "description" => "ok",
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
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      raw_schema =
        resolved["paths"]["/x"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      parsed = Portico.Spec.Schema.parse(raw_schema)

      assert parsed.ref == "#/components/schemas/User"
      assert parsed.type == "object"
      # properties are still accessible for inline uses like doc generation
      assert Map.has_key?(parsed.properties, "id")
    end

    test "components.schemas entries keep $ref on child references, not on themselves" do
      # Important invariant: we must not accidentally tag the definitional
      # entries in components.schemas with a $ref, or downstream code would
      # think User is "a reference to itself" and loop.
      spec = %{
        "components" => %{
          "schemas" => %{
            "User" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "friend" => %{"$ref" => "#/components/schemas/User"}
              }
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      user = resolved["components"]["schemas"]["User"]

      refute Map.has_key?(user, "$ref")
      assert user["properties"]["friend"]["$ref"] == "#/components/schemas/User"
    end

    test "JSON Pointer with escaped characters still resolves schema refs correctly" do
      spec = %{
        "paths" => %{
          "/x" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/weird~1name"}
                    }
                  }
                }
              }
            }
          }
        },
        "components" => %{
          "schemas" => %{
            "weird/name" => %{"type" => "object", "properties" => %{}}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      schema =
        resolved["paths"]["/x"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      # The preserved $ref keeps the escaped (original) form, not the decoded form.
      assert schema["$ref"] == "#/components/schemas/weird~1name"
      assert schema["type"] == "object"
    end

    test "ref to something that is not a schema-path is NOT treated as a schema ref" do
      # Only refs starting with #/components/schemas/ are preserved. Refs to
      # other components (parameters, requestBodies, responses, headers) are
      # fully inlined even if the referenced value happens to be schema-shaped.
      spec = %{
        "paths" => %{
          "/x" => %{
            "post" => %{
              "parameters" => [%{"$ref" => "#/components/parameters/SchemaShaped"}]
            }
          }
        },
        "components" => %{
          "parameters" => %{
            "SchemaShaped" => %{
              "in" => "query",
              "name" => "q",
              "schema" => %{"type" => "string"}
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)
      [param] = resolved["paths"]["/x"]["post"]["parameters"]

      refute Map.has_key?(param, "$ref")
      assert param["in"] == "query"
    end

    test "large-but-valid schema refs still get tagged even when skipped from cache" do
      # The resolver skips caching for maps with > 100 keys. Make sure we
      # still preserve the $ref tag for those.
      big_properties =
        for i <- 1..150, into: %{}, do: {"field_#{i}", %{"type" => "string"}}

      spec = %{
        "paths" => %{
          "/x" => %{
            "get" => %{
              "responses" => %{
                "200" => %{
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/Huge"}
                    }
                  }
                }
              }
            }
          }
        },
        "components" => %{
          "schemas" => %{
            "Huge" => %{"type" => "object", "properties" => big_properties}
          }
        }
      }

      resolved = Resolver.resolve(spec)

      schema =
        resolved["paths"]["/x"]["get"]["responses"]["200"]["content"]["application/json"][
          "schema"
        ]

      assert schema["$ref"] == "#/components/schemas/Huge"
      assert map_size(schema["properties"]) == 150
    end

    test "schema ref under allOf/oneOf/anyOf is preserved" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "Animal" => %{"type" => "object", "properties" => %{"kind" => %{"type" => "string"}}},
            "Dog" => %{
              "allOf" => [
                %{"$ref" => "#/components/schemas/Animal"},
                %{"type" => "object", "properties" => %{"bark" => %{"type" => "boolean"}}}
              ]
            },
            "Cat" => %{
              "oneOf" => [
                %{"$ref" => "#/components/schemas/Animal"},
                %{"type" => "object", "properties" => %{"meow" => %{"type" => "boolean"}}}
              ]
            },
            "Pet" => %{
              "anyOf" => [
                %{"$ref" => "#/components/schemas/Dog"},
                %{"$ref" => "#/components/schemas/Cat"}
              ]
            }
          }
        }
      }

      resolved = Resolver.resolve(spec)

      [dog_base | _] = resolved["components"]["schemas"]["Dog"]["allOf"]
      [cat_base | _] = resolved["components"]["schemas"]["Cat"]["oneOf"]
      [pet_first, pet_second] = resolved["components"]["schemas"]["Pet"]["anyOf"]

      assert dog_base["$ref"] == "#/components/schemas/Animal"
      assert cat_base["$ref"] == "#/components/schemas/Animal"
      assert pet_first["$ref"] == "#/components/schemas/Dog"
      assert pet_second["$ref"] == "#/components/schemas/Cat"
    end

    test "does not mutate the input spec map" do
      original = %{
        "components" => %{
          "schemas" => %{
            "User" => %{"type" => "object", "properties" => %{"id" => %{"type" => "integer"}}},
            "Post" => %{
              "type" => "object",
              "properties" => %{"author" => %{"$ref" => "#/components/schemas/User"}}
            }
          }
        }
      }

      _ = Resolver.resolve(original)

      # The original spec map should still have only the $ref in author, no
      # inlined "type"/"properties" bleed-through.
      assert original["components"]["schemas"]["Post"]["properties"]["author"] ==
               %{"$ref" => "#/components/schemas/User"}
    end
  end
end
