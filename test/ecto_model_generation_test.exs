defmodule EctoModelGenerationTest do
  use ExUnit.Case

  @test_spec %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "Model Test API",
      "version" => "1.0.0"
    },
    "paths" => %{
      "/users/{id}" => %{
        "get" => %{
          "operationId" => "getUser",
          "summary" => "Get a user by ID",
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
              "description" => "User found",
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
          "description" => "A user in the system",
          "properties" => %{
            "id" => %{
              "type" => "integer",
              "description" => "User ID"
            },
            "name" => %{
              "type" => "string",
              "description" => "User name"
            },
            "email" => %{
              "type" => "string",
              "format" => "email",
              "description" => "User email"
            },
            "created_at" => %{
              "type" => "string",
              "format" => "date-time",
              "description" => "Account creation timestamp"
            },
            "score" => %{
              "type" => "number",
              "description" => "User score"
            },
            "is_active" => %{
              "type" => "boolean",
              "description" => "Whether the user is active"
            },
            "tags" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "User tags"
            },
            "metadata" => %{
              "type" => "object",
              "description" => "Additional metadata",
              "properties" => %{
                "key" => %{"type" => "string"},
                "value" => %{"type" => "string"}
              }
            }
          },
          "required" => ["id", "name", "email"]
        }
      }
    }
  }

  setup_all do
    # Create a temporary directory for testing
    {:ok, temp_dir} = Briefly.create(type: :directory)

    # Create test spec file
    spec_file = Path.join(temp_dir, "model_test_spec.json")
    File.write!(spec_file, Jason.encode!(@test_spec))

    # Use the mix task directly instead of System.cmd
    import ExUnit.CaptureIO

    _output =
      capture_io(fn ->
        # Change to temp dir for generation
        File.cd!(temp_dir, fn ->
          Mix.Tasks.Portico.Generate.run(["--module", "ModelTestAPI", "--spec", spec_file])
        end)
      end)

    %{temp_dir: temp_dir}
  end

  describe "Ecto model generation" do
    test "generates models with Ecto schemas", %{temp_dir: temp_dir} do
      model_file = Path.join(temp_dir, "lib/model_test_api/models/user.ex")
      assert File.exists?(model_file)

      content = File.read!(model_file)

      # Check for Ecto schema usage
      assert content =~ "use Ecto.Schema"
      assert content =~ "import Ecto.Changeset"
      assert content =~ "embedded_schema do"

      # Check for proper field definitions
      assert content =~ "field(:id, :integer)"
      assert content =~ "field(:name, :string)"
      assert content =~ "field(:email, :string)"
      assert content =~ "field(:created_at, :utc_datetime)"
      assert content =~ "field(:score, :decimal)"
      assert content =~ "field(:is_active, :boolean)"
      assert content =~ "field(:tags, {:array, :string})"
      # Inline object becomes map
      assert content =~ "field(:metadata, :map)"
    end

    test "generates models with centralized helpers", %{temp_dir: temp_dir} do
      model_file = Path.join(temp_dir, "lib/model_test_api/models/user.ex")
      content = File.read!(model_file)

      # Check for centralized helpers usage
      assert content =~ "alias Portico.Runtime.ModelHelpers"
      assert content =~ "ModelHelpers.normalize_params"
      assert content =~ "ModelHelpers.apply_changeset_permissively"
      assert content =~ "ModelHelpers.struct_to_json"

      # Should NOT have duplicated helper functions
      refute content =~ "defp parse_date"
      refute content =~ "defp parse_datetime"
      refute content =~ "defp serialize_value"
    end

    test "generates from_json and to_json functions", %{temp_dir: temp_dir} do
      model_file = Path.join(temp_dir, "lib/model_test_api/models/user.ex")
      content = File.read!(model_file)

      # Check for conversion functions
      assert content =~ "@spec from_json(map() | nil) :: t() | nil"
      assert content =~ "def from_json(nil), do: nil"
      assert content =~ "def from_json(params) when is_map(params)"

      assert content =~ "@spec to_json(t()) :: map()"
      assert content =~ "def to_json(%__MODULE__{} = struct)"
    end

    test "generates changeset function for validation", %{temp_dir: temp_dir} do
      model_file = Path.join(temp_dir, "lib/model_test_api/models/user.ex")
      content = File.read!(model_file)

      # Check for changeset function
      assert content =~ "def changeset(struct, params)"
      assert content =~ "|> cast(params"
    end

    test "API functions include model option for automatic conversion", %{temp_dir: temp_dir} do
      # Check the generated API file
      api_dir = Path.join(temp_dir, "lib/model_test_api/api")
      api_files = File.ls!(api_dir)

      # Should have at least one API file
      assert length(api_files) > 0

      # Read the first API file
      api_file = Path.join(api_dir, hd(api_files))
      content = File.read!(api_file)

      # Check for model option in the request
      # Since the response has a $ref to User, it should include the model
      assert content =~ "model: ModelTestAPI.Models."
    end

    test "client includes model conversion logic", %{temp_dir: temp_dir} do
      client_file = Path.join(temp_dir, "lib/model_test_api/client.ex")
      content = File.read!(client_file)

      # Check for model conversion functions
      assert content =~ "convert_response"
      assert content =~ "model.from_json"
      assert content =~ "{model, options} = Keyword.pop(options, :model)"
    end
  end

  describe "no-models flag" do
    test "does not generate models when --no-models is used" do
      {:ok, temp_dir} = Briefly.create(type: :directory)
      spec_file = Path.join(temp_dir, "no_models_spec.json")
      File.write!(spec_file, Jason.encode!(@test_spec))

      import ExUnit.CaptureIO

      capture_io(fn ->
        File.cd!(temp_dir, fn ->
          Mix.Tasks.Portico.Generate.run([
            "--module",
            "NoModelsTestAPI",
            "--spec",
            spec_file,
            "--no-models"
          ])
        end)
      end)

      # Models directory should not exist
      models_dir = Path.join(temp_dir, "lib/no_models_test_api/models")
      refute File.exists?(models_dir)

      # API functions should not include model option
      api_dir = Path.join(temp_dir, "lib/no_models_test_api/api")
      api_files = File.ls!(api_dir)

      if length(api_files) > 0 do
        api_file = Path.join(api_dir, hd(api_files))
        content = File.read!(api_file)
        refute content =~ "model:"
      end

      # Client should not have model conversion code
      client_file = Path.join(temp_dir, "lib/no_models_test_api/client.ex")
      content = File.read!(client_file)
      refute content =~ "convert_response"
      refute content =~ "model.from_json"
    end
  end
end
