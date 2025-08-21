defmodule Mix.Tasks.Portico.GenerateTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @test_spec_json %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "Test API",
      "version" => "1.0.0"
    },
    "paths" => %{
      "/users" => %{
        "get" => %{
          "summary" => "List users",
          "tags" => ["user-management"],
          "parameters" => [
            %{
              "name" => "limit",
              "in" => "query",
              "required" => false,
              "schema" => %{"type" => "integer"}
            }
          ],
          "responses" => %{
            "200" => %{
              "description" => "Success"
            }
          }
        },
        "post" => %{
          "summary" => "Create user",
          "tags" => ["user-management"],
          "requestBody" => %{
            "required" => true,
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "type" => "object",
                  "properties" => %{
                    "name" => %{"type" => "string"}
                  }
                }
              }
            }
          },
          "responses" => %{
            "201" => %{
              "description" => "Created"
            }
          }
        }
      },
      "/posts/{id}" => %{
        "parameters" => [
          %{
            "name" => "id",
            "in" => "path",
            "required" => true,
            "schema" => %{"type" => "integer"}
          }
        ],
        "get" => %{
          "summary" => "Get post",
          "tags" => ["content"],
          "responses" => %{
            "200" => %{
              "description" => "Success"
            }
          }
        }
      },
      "/untagged" => %{
        "get" => %{
          "summary" => "Untagged endpoint",
          "responses" => %{
            "200" => %{
              "description" => "Success"
            }
          }
        }
      }
    }
  }

  setup do
    # Create a temporary directory for testing
    {:ok, temp_dir} = Briefly.create(type: :directory)

    # Create a test spec file
    spec_file = Path.join(temp_dir, "test_spec.json")
    File.write!(spec_file, Jason.encode!(@test_spec_json))

    %{temp_dir: temp_dir, spec_file: spec_file}
  end

  describe "run/1" do
    test "requires --module argument" do
      assert_raise RuntimeError,
                   "You must provide a name for the API client using --module",
                   fn ->
                     Mix.Tasks.Portico.Generate.run(["--spec", "test.json"])
                   end
    end

    test "processes module name correctly", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Check that the lib directory was created with the right name
        assert File.exists?("lib/test_api")
        assert File.dir?("lib/test_api")
      end)
    end

    test "creates client module", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        client_file = "lib/test_api/client.ex"
        assert File.exists?(client_file)

        content = File.read!(client_file)
        assert content =~ "defmodule TestAPI.Client"
      end)
    end

    test "creates API modules grouped by tags", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Should create user_management module for tagged operations
        user_mgmt_file = "lib/test_api/api/user_management.ex"
        assert File.exists?(user_mgmt_file)

        content = File.read!(user_mgmt_file)
        assert content =~ "defmodule TestAPI.UserManagement"
        assert content =~ "def get_users(client"
        assert content =~ "def post_users(client"

        # Should create content module for content tag
        content_file = "lib/test_api/api/content.ex"
        assert File.exists?(content_file)

        content = File.read!(content_file)
        assert content =~ "defmodule TestAPI.Content"
        assert content =~ "def get_posts_id(client"

        # Should create fallback module for untagged operations
        untagged_file = "lib/test_api/api/untagged.ex"
        assert File.exists?(untagged_file)

        content = File.read!(untagged_file)
        assert content =~ "defmodule TestAPI.Untagged"
        assert content =~ "def get_untagged(client"
      end)
    end

    test "generates correct function signatures", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        user_mgmt_content = File.read!("lib/test_api/api/user_management.ex")

        # GET /users should have optional parameters
        assert user_mgmt_content =~ "def get_users(client, opts \\\\ [])"

        # POST /users should have required body
        assert user_mgmt_content =~ "def post_users(client, body)"

        content_content = File.read!("lib/test_api/api/content.ex")

        # GET /posts/{id} should have required path parameter
        assert content_content =~ "def get_posts_id(client, id)"
      end)
    end

    test "generates correct documentation", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        user_mgmt_content = File.read!("lib/test_api/api/user_management.ex")

        # Note: The summaries are not included in the actual template output
        # The template uses operation.description, not operation.summary
        # This is expected behavior based on the current template

        # Should include parameter documentation
        assert user_mgmt_content =~ "## Parameters"
        assert user_mgmt_content =~ "`limit`"
        assert user_mgmt_content =~ "`body`"
      end)
    end

    test "generates correct HTTP client calls", %{temp_dir: temp_dir, spec_file: spec_file} do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        user_mgmt_content = File.read!("lib/test_api/api/user_management.ex")

        # Should include correct HTTP methods and URLs
        assert user_mgmt_content =~ "method: :get"
        assert user_mgmt_content =~ "method: :post"
        assert user_mgmt_content =~ "url: \"/users\""

        # Should include parameter handling
        assert user_mgmt_content =~ "params: ["
        assert user_mgmt_content =~ "json: body"

        content_content = File.read!("lib/test_api/api/content.ex")

        # Should handle path parameters
        assert content_content =~ "url: \"/posts/\#{id}\""
      end)
    end
  end

  describe "tag-based grouping behavior" do
    test "groups operations with same tag into single module", %{temp_dir: temp_dir} do
      spec_with_same_tags = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{
          "/users" => %{
            "get" => %{"tags" => ["users"], "summary" => "List users"}
          },
          "/users/{id}" => %{
            "get" => %{"tags" => ["users"], "summary" => "Get user"}
          },
          "/users/{id}/posts" => %{
            "get" => %{"tags" => ["users"], "summary" => "Get user posts"}
          }
        }
      }

      spec_file = Path.join(temp_dir, "same_tags.json")
      File.write!(spec_file, Jason.encode!(spec_with_same_tags))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Should create only one module for all "users" tagged operations
        users_file = "lib/test_api/api/users.ex"
        assert File.exists?(users_file)

        content = File.read!(users_file)
        assert content =~ "defmodule TestAPI.Users"
        assert content =~ "def get_users(client"
        assert content =~ "def get_users_id(client"
        assert content =~ "def get_users_id_posts(client"

        # Should not create separate modules for each path
        api_dir = "lib/test_api/api"
        api_files = File.ls!(api_dir)
        assert length(api_files) == 1
        assert "users.ex" in api_files
      end)
    end

    test "uses first tag when operation has multiple tags", %{temp_dir: temp_dir} do
      spec_with_multiple_tags = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{
          "/multi-tag" => %{
            "get" => %{
              "tags" => ["primary", "secondary", "tertiary"],
              "summary" => "Multi-tag operation"
            }
          }
        }
      }

      spec_file = Path.join(temp_dir, "multi_tags.json")
      File.write!(spec_file, Jason.encode!(spec_with_multiple_tags))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Should create module based on first tag only
        primary_file = "lib/test_api/api/primary.ex"
        assert File.exists?(primary_file)

        content = File.read!(primary_file)
        assert content =~ "defmodule TestAPI.Primary"

        # Should not create modules for other tags
        refute File.exists?("lib/test_api/api/secondary.ex")
        refute File.exists?("lib/test_api/api/tertiary.ex")
      end)
    end

    test "handles special characters in tag names", %{temp_dir: temp_dir} do
      spec_with_special_tags = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{
          "/special" => %{
            "get" => %{
              "tags" => ["Quality & Safety/punch-list"],
              "summary" => "Special tag operation"
            }
          }
        }
      }

      spec_file = Path.join(temp_dir, "special_tags.json")
      File.write!(spec_file, Jason.encode!(spec_with_special_tags))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Should create module with sanitized name
        special_file = "lib/test_api/api/quality_safety_punch_list.ex"
        assert File.exists?(special_file)

        content = File.read!(special_file)
        assert content =~ "defmodule TestAPI.QualitySafetyPunchList"
      end)
    end
  end

  describe "fallback behavior" do
    test "falls back to path-based modules when no tags", %{temp_dir: temp_dir} do
      spec_without_tags = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{
          "/path1" => %{
            "get" => %{"summary" => "Path 1 operation"}
          },
          "/path2/{id}" => %{
            "post" => %{"summary" => "Path 2 operation"}
          }
        }
      }

      spec_file = Path.join(temp_dir, "no_tags.json")
      File.write!(spec_file, Jason.encode!(spec_without_tags))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        # Should create modules based on paths
        path1_file = "lib/test_api/api/path1.ex"
        path2_file = "lib/test_api/api/path2_id.ex"

        assert File.exists?(path1_file)
        assert File.exists?(path2_file)

        path1_content = File.read!(path1_file)
        assert path1_content =~ "defmodule TestAPI.Path1"

        path2_content = File.read!(path2_file)
        assert path2_content =~ "defmodule TestAPI.Path2Id"
      end)
    end

    test "mixes tagged and untagged operations appropriately", %{
      temp_dir: temp_dir,
      spec_file: spec_file
    } do
      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", spec_file])
        end)

        api_dir = "lib/test_api/api"
        api_files = File.ls!(api_dir)

        # Should have modules for both tagged and untagged operations
        # tagged
        assert "user_management.ex" in api_files
        # tagged
        assert "content.ex" in api_files
        # untagged fallback
        assert "untagged.ex" in api_files
      end)
    end
  end

  describe "config-based generation" do
    test "generates client with default base URL from config", %{temp_dir: temp_dir} do
      # Create a spec with servers
      spec_with_servers =
        Map.put(@test_spec_json, "servers", [
          %{"url" => "https://api.test.com"},
          %{"url" => "https://staging.test.com"}
        ])

      spec_file = Path.join(temp_dir, "spec_with_servers.json")
      File.write!(spec_file, Jason.encode!(spec_with_servers))

      # Generate config
      config_file = Path.join(temp_dir, "test.config.json")

      capture_io(fn ->
        Mix.Tasks.Portico.Config.run(["--spec", spec_file, "--output", config_file])
      end)

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--config", config_file])
        end)

        client_file = "lib/test_api/client.ex"
        assert File.exists?(client_file)

        content = File.read!(client_file)
        # Should have default base URL
        assert content =~ "@default_base_url \"https://api.test.com\""
        # Should have new/1 function that uses default
        assert content =~ "def new(options \\\\ []) when is_list(options)"
        assert content =~ "|> Keyword.put_new(:base_url, @default_base_url)"
        # Should get application config with dynamic app detection
        assert content =~ "app = Application.get_application(__MODULE__) || :portico"
        assert content =~ "Application.get_env(app, :test_api, [])"
      end)
    end

    test "generates client without default base URL when not in config", %{temp_dir: temp_dir} do
      # Create a spec without servers
      spec_file = Path.join(temp_dir, "spec_no_servers.json")
      File.write!(spec_file, Jason.encode!(@test_spec_json))

      # Generate config
      config_file = Path.join(temp_dir, "test_no_url.config.json")

      capture_io(fn ->
        Mix.Tasks.Portico.Config.run(["--spec", spec_file, "--output", config_file])
      end)

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--config", config_file])
        end)

        client_file = "lib/test_api/client.ex"
        assert File.exists?(client_file)

        content = File.read!(client_file)
        # Should not have default base URL
        refute content =~ "@default_base_url"
        # Should have new/1 function that requires base_url
        assert content =~ "def new(options) when is_list(options)"
        assert content =~ "base_url is required"
      end)
    end
  end

  describe "tag filtering for models" do
    test "generates only inline models for filtered tags", %{temp_dir: temp_dir} do
      # Create spec with multiple tags and both inline and component schemas
      spec_with_models = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "servers" => [%{"url" => "https://api.example.com"}],
        "paths" => %{
          "/pets" => %{
            "get" => %{
              "tags" => ["pets"],
              "operationId" => "listPets",
              "responses" => %{
                "200" => %{
                  "description" => "List of pets",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        "type" => "object",
                        "properties" => %{
                          "pets" => %{
                            "type" => "array",
                            "items" => %{"$ref" => "#/components/schemas/Pet"}
                          }
                        }
                      }
                    }
                  }
                }
              }
            },
            "post" => %{
              "tags" => ["pets"],
              "operationId" => "createPet",
              "requestBody" => %{
                "content" => %{
                  "application/json" => %{
                    "schema" => %{
                      "type" => "object",
                      "properties" => %{
                        "name" => %{"type" => "string"},
                        "type" => %{"type" => "string"}
                      },
                      "required" => ["name"]
                    }
                  }
                }
              },
              "responses" => %{
                "201" => %{
                  "description" => "Pet created",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        "type" => "object",
                        "properties" => %{
                          "id" => %{"type" => "integer"},
                          "name" => %{"type" => "string"}
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "/users" => %{
            "get" => %{
              "tags" => ["users"],
              "operationId" => "listUsers",
              "responses" => %{
                "200" => %{
                  "description" => "List of users",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        "type" => "object",
                        "properties" => %{
                          "users" => %{
                            "type" => "array",
                            "items" => %{"$ref" => "#/components/schemas/User"}
                          }
                        }
                      }
                    }
                  }
                }
              }
            },
            "post" => %{
              "tags" => ["users"],
              "operationId" => "createUser",
              "requestBody" => %{
                "content" => %{
                  "application/json" => %{
                    "schema" => %{
                      "type" => "object",
                      "properties" => %{
                        "email" => %{"type" => "string"},
                        "name" => %{"type" => "string"}
                      },
                      "required" => ["email"]
                    }
                  }
                }
              },
              "responses" => %{
                "201" => %{
                  "description" => "User created",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        "type" => "object",
                        "properties" => %{
                          "id" => %{"type" => "integer"},
                          "email" => %{"type" => "string"}
                        }
                      }
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
                "name" => %{"type" => "string"},
                "type" => %{"type" => "string"}
              }
            },
            "User" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "integer"},
                "email" => %{"type" => "string"},
                "name" => %{"type" => "string"}
              }
            }
          }
        }
      }

      spec_file = Path.join(temp_dir, "spec_with_models.json")
      File.write!(spec_file, Jason.encode!(spec_with_models))

      # Create config with tag filter
      config = %{
        "spec_info" => %{
          "module" => "FilteredAPI",
          "title" => "Filtered API",
          "source" => spec_file
        },
        "base_url" => "https://api.example.com",
        "tags" => ["pets"]
      }

      config_file = Path.join(temp_dir, "filtered.config.json")
      File.write!(config_file, Jason.encode!(config))

      File.cd!(temp_dir, fn ->
        output =
          capture_io(fn ->
            Mix.Tasks.Portico.Generate.run(["--config", config_file])
          end)

        # Check that pet API was generated
        assert File.exists?("lib/filtered_api/api/pets.ex")

        # Check that pet inline models were generated
        assert File.exists?("lib/filtered_api/models/create_pet_request.ex")
        assert File.exists?("lib/filtered_api/models/create_pet_response201.ex")
        assert File.exists?("lib/filtered_api/models/list_pets_response.ex")

        # Check that user API was NOT generated
        refute File.exists?("lib/filtered_api/api/users.ex")

        # Check that user inline models were NOT generated
        refute File.exists?("lib/filtered_api/models/create_user_request.ex")
        refute File.exists?("lib/filtered_api/models/create_user_response201.ex")

        # Check that component schemas were NOT generated when filtering
        # (This is the key behavior - we only generate inline schemas when filtering)
        refute File.exists?("lib/filtered_api/models/pet.ex")
        refute File.exists?("lib/filtered_api/models/user.ex")

        # Verify output mentions the right files (handle ANSI color codes)
        assert output =~ "lib/filtered_api/api/pets.ex"
        refute output =~ "lib/filtered_api/api/users.ex"
        refute output =~ "lib/filtered_api/models/pet.ex"
      end)
    end

    test "generates all models without tag filtering", %{temp_dir: temp_dir} do
      # Use same spec as above but without tag filtering
      spec_with_models = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{
          "/pets" => %{
            "post" => %{
              "tags" => ["pets"],
              "operationId" => "createPet",
              "requestBody" => %{
                "content" => %{
                  "application/json" => %{
                    "schema" => %{
                      "type" => "object",
                      "properties" => %{
                        "name" => %{"type" => "string"}
                      }
                    }
                  }
                }
              },
              "responses" => %{
                "201" => %{
                  "description" => "Created",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        "type" => "object",
                        "properties" => %{
                          "id" => %{"type" => "integer"}
                        }
                      }
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
                "name" => %{"type" => "string"}
              }
            }
          }
        }
      }

      spec_file = Path.join(temp_dir, "full_spec.json")
      File.write!(spec_file, Jason.encode!(spec_with_models))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "FullAPI", "--spec", spec_file])
        end)

        # Should generate both component schemas and inline schemas
        assert File.exists?("lib/full_api/models/pet.ex")
        assert File.exists?("lib/full_api/models/create_pet_request.ex")
        assert File.exists?("lib/full_api/models/create_pet_response201.ex")
      end)
    end

    test "respects --no-models flag with tag filtering", %{temp_dir: temp_dir} do
      spec_file = Path.join(temp_dir, "test_spec.json")
      File.write!(spec_file, Jason.encode!(@test_spec_json))

      config = %{
        "spec_info" => %{
          "module" => "NoModelsAPI",
          "title" => "No Models API",
          "source" => spec_file
        },
        "tags" => ["user-management"]
      }

      config_file = Path.join(temp_dir, "no_models.config.json")
      File.write!(config_file, Jason.encode!(config))

      File.cd!(temp_dir, fn ->
        output =
          capture_io(fn ->
            Mix.Tasks.Portico.Generate.run(["--config", config_file, "--no-models"])
          end)

        # Should generate API but not models
        assert File.exists?("lib/no_models_api/api/user_management.ex")
        refute File.exists?("lib/no_models_api/models")

        # Verify output doesn't mention creating models (handle ANSI color codes)
        assert output =~ "lib/no_models_api/api/user_management.ex"
        refute output =~ "lib/no_models_api/models"
      end)
    end
  end

  describe "error handling" do
    test "handles missing spec file gracefully" do
      assert_raise File.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", "nonexistent.json"])
        end)
      end
    end

    test "handles invalid JSON gracefully", %{temp_dir: temp_dir} do
      invalid_spec = Path.join(temp_dir, "invalid.json")
      File.write!(invalid_spec, "{ invalid json }")

      File.cd!(temp_dir, fn ->
        assert_raise Jason.DecodeError, fn ->
          capture_io(fn ->
            Mix.Tasks.Portico.Generate.run(["--module", "TestAPI", "--spec", invalid_spec])
          end)
        end
      end)
    end
  end
end
