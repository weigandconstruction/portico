defmodule AutomaticModelConversionTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @test_spec %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "Test API",
      "version" => "1.0.0"
    },
    "servers" => [
      %{"url" => "https://api.example.com"}
    ],
    "paths" => %{
      "/posts/{id}" => %{
        "get" => %{
          "operationId" => "getPost",
          "summary" => "Get a post by ID",
          "parameters" => [
            %{
              "name" => "id",
              "in" => "path",
              "required" => true,
              "schema" => %{"type" => "string"}
            }
          ],
          "responses" => %{
            "200" => %{
              "description" => "Post found",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "description" => "A blog post",
                    "properties" => %{
                      "id" => %{
                        "type" => "integer",
                        "description" => "Post ID"
                      },
                      "title" => %{
                        "type" => "string",
                        "description" => "Post title"
                      },
                      "body" => %{
                        "type" => "string",
                        "description" => "Post content"
                      },
                      "published_at" => %{
                        "type" => "string",
                        "format" => "date-time",
                        "description" => "Publication timestamp"
                      },
                      "author" => %{
                        "type" => "object",
                        "description" => "Post author",
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
          }
        }
      }
    }
  }

  setup do
    # Create temporary directories for both test cases
    {:ok, temp_dir_with_models} = Briefly.create(type: :directory)
    {:ok, temp_dir_no_models} = Briefly.create(type: :directory)

    # Create test spec files
    spec_file_with_models = Path.join(temp_dir_with_models, "test_spec.json")
    spec_file_no_models = Path.join(temp_dir_no_models, "test_spec.json")

    File.write!(spec_file_with_models, Jason.encode!(@test_spec))
    File.write!(spec_file_no_models, Jason.encode!(@test_spec))

    # Generate API with models
    File.cd!(temp_dir_with_models, fn ->
      capture_io(fn ->
        Mix.Tasks.Portico.Generate.run(["--module", "EctoTestAPI", "--spec", "test_spec.json"])
      end)
    end)

    # Generate API without models
    File.cd!(temp_dir_no_models, fn ->
      capture_io(fn ->
        Mix.Tasks.Portico.Generate.run([
          "--module",
          "NoModelsAPI",
          "--spec",
          "test_spec.json",
          "--no-models"
        ])
      end)
    end)

    {:ok, temp_dir_with_models: temp_dir_with_models, temp_dir_no_models: temp_dir_no_models}
  end

  describe "automatic model conversion in API functions" do
    test "API functions with models automatically convert responses", %{
      temp_dir_with_models: temp_dir
    } do
      # Read the generated API file to verify model option is present
      api_file = Path.join([temp_dir, "lib", "ecto_test_api", "api", "posts_id.ex"])
      api_code = File.read!(api_file)

      # Check that the model option is included
      assert api_code =~ "model: EctoTestAPI.Models.GetPostResponse"
    end

    test "API functions without models don't include model option", %{
      temp_dir_no_models: temp_dir
    } do
      # Read the generated API file
      api_file = Path.join([temp_dir, "lib", "no_models_api", "api", "posts_id.ex"])
      api_code = File.read!(api_file)

      # Check that the model option is NOT included
      refute api_code =~ "model:"
    end

    test "Client.request handles model conversion when model option is provided", %{
      temp_dir_with_models: temp_dir
    } do
      # Read the client file to verify conversion logic exists
      client_file = Path.join([temp_dir, "lib", "ecto_test_api", "client.ex"])
      client_code = File.read!(client_file)

      # Check for the conversion function
      assert client_code =~ "convert_response"
      assert client_code =~ "model.from_json"
    end

    test "models are generated correctly for inline schemas", %{
      temp_dir_with_models: temp_dir
    } do
      # Check that the GetPostResponse model was created
      model_file = Path.join([temp_dir, "lib", "ecto_test_api", "models", "get_post_response.ex"])
      assert File.exists?(model_file)

      model_code = File.read!(model_file)

      # Verify the model has correct fields
      assert model_code =~ "field(:id, :integer)"
      assert model_code =~ "field(:title, :string)"
      assert model_code =~ "field(:body, :string)"
      assert model_code =~ "field(:published_at, :utc_datetime)"
      assert model_code =~ "field(:author, :map)"

      # Verify it uses Ecto.Schema
      assert model_code =~ "use Ecto.Schema"
      assert model_code =~ "import Ecto.Changeset"
      assert model_code =~ "alias Portico.Runtime.ModelHelpers"
    end

    test "no models directory is created with --no-models flag", %{
      temp_dir_no_models: temp_dir
    } do
      # Check that no models directory was created
      models_dir = Path.join([temp_dir, "lib", "no_models_api", "models"])
      refute File.exists?(models_dir)
    end
  end
end
