defmodule GeneratedModelRuntimeTest do
  @moduledoc """
  End-to-end tests that generate an API client, compile the generated models,
  and exercise `from_json/1` and `to_json/1` against realistic JSON payloads.

  The rest of the suite asserts on generated *source text*. These tests assert
  on generated *behavior* — the thing that actually matters for consumers.
  """
  use ExUnit.Case
  import ExUnit.CaptureIO

  @spec_fixture %{
    "openapi" => "3.0.0",
    "info" => %{"title" => "Runtime Test API", "version" => "1.0.0"},
    "paths" => %{
      "/users/{id}" => %{
        "get" => %{
          "operationId" => "getUser",
          "tags" => ["users"],
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
          "required" => ["id", "userName"],
          "properties" => %{
            "id" => %{"type" => "integer"},
            "userName" => %{"type" => "string"},
            "emailAddress" => %{"type" => "string"},
            "isActive" => %{"type" => "boolean"},
            "createdAt" => %{"type" => "string", "format" => "date-time"},
            "birthDate" => %{"type" => "string", "format" => "date"},
            "favoriteColors" => %{"type" => "array", "items" => %{"type" => "string"}}
          }
        }
      }
    }
  }

  setup_all do
    {:ok, temp_dir} = Briefly.create(type: :directory)
    spec_file = Path.join(temp_dir, "spec.json")
    File.write!(spec_file, Jason.encode!(@spec_fixture))

    # Pick a unique module prefix per test run so we never collide with an
    # already-loaded module from a previous iex session or a prior test
    # setup_all run inside the same VM.
    suffix = System.unique_integer([:positive])
    module_name = "RuntimeGen#{suffix}API"
    dir_name = Macro.underscore(module_name)

    capture_io(fn ->
      File.cd!(temp_dir, fn ->
        Mix.Tasks.Portico.Generate.run(["--module", module_name, "--spec", spec_file])
      end)
    end)

    # Compile the local ModelHelpers first — the generated User module
    # aliases it — then the User module itself.
    helpers_path = Path.join([temp_dir, "lib", dir_name, "model_helpers.ex"])
    Code.compile_file(helpers_path)

    user_path = Path.join([temp_dir, "lib", dir_name, "models", "user.ex"])
    [{user_module, _bytecode}] = Code.compile_file(user_path)

    {:ok, user: user_module, temp_dir: temp_dir, module_name: module_name, dir_name: dir_name}
  end

  describe "from_json/1 JSON key handling" do
    test "casts camelCase JSON keys to their snake_case fields", %{user: user} do
      json = %{
        "id" => 42,
        "userName" => "alice",
        "emailAddress" => "alice@example.com",
        "isActive" => true,
        "createdAt" => "2024-01-15T10:30:00Z",
        "birthDate" => "1990-05-01",
        "favoriteColors" => ["red", "blue"]
      }

      result = user.from_json(json)

      # Every camelCase key should have populated its snake_case field.
      # A silent drop here is the primary bug the generator historically had.
      assert result.id == 42
      assert result.user_name == "alice"
      assert result.email_address == "alice@example.com"
      assert result.is_active == true
      assert result.favorite_colors == ["red", "blue"]
    end

    test "parses date and datetime fields from strings", %{user: user} do
      json = %{
        "id" => 1,
        "userName" => "x",
        "createdAt" => "2024-01-15T10:30:00Z",
        "birthDate" => "1990-05-01"
      }

      result = user.from_json(json)

      assert %DateTime{year: 2024, month: 1, day: 15} = result.created_at
      assert %Date{year: 1990, month: 5, day: 1} = result.birth_date
    end

    test "returns nil for missing optional fields", %{user: user} do
      json = %{"id" => 1, "userName" => "x"}

      result = user.from_json(json)

      assert result.id == 1
      assert result.user_name == "x"
      assert result.email_address == nil
      assert result.is_active == nil
      assert result.created_at == nil
    end

    test "handles non-renamed fields (matching JSON key = field name)", %{user: user} do
      json = %{"id" => 1, "userName" => "x"}

      result = user.from_json(json)

      # `id` is not renamed — this path should always work, independent of
      # the camelCase fix. Covers the regression risk of the fix breaking
      # the common case.
      assert result.id == 1
    end

    test "handles nil input", %{user: user} do
      assert user.from_json(nil) == nil
    end
  end

  describe "to_json/1 round-trip" do
    test "round-trips camelCase JSON through from_json |> to_json", %{user: user} do
      original = %{
        "id" => 7,
        "userName" => "bob",
        "emailAddress" => "bob@example.com",
        "isActive" => false,
        "favoriteColors" => ["green"]
      }

      serialized = original |> user.from_json() |> user.to_json()

      # Every key present in the original must come back with the same
      # camelCase spelling. The original test suite never caught regressions
      # here because it only asserted on source text.
      assert serialized["id"] == 7
      assert serialized["userName"] == "bob"
      assert serialized["emailAddress"] == "bob@example.com"
      assert serialized["isActive"] == false
      assert serialized["favoriteColors"] == ["green"]
    end

    test "serializes Date and DateTime back to ISO 8601 strings", %{user: user} do
      json = %{
        "id" => 1,
        "userName" => "x",
        "createdAt" => "2024-01-15T10:30:00Z",
        "birthDate" => "1990-05-01"
      }

      serialized = json |> user.from_json() |> user.to_json()

      assert serialized["createdAt"] == "2024-01-15T10:30:00Z"
      assert serialized["birthDate"] == "1990-05-01"
    end
  end

  describe "runtime independence from portico" do
    test "generates a local ModelHelpers module in the API tree", %{
      temp_dir: temp_dir,
      dir_name: dir_name
    } do
      helpers_path = Path.join([temp_dir, "lib", dir_name, "model_helpers.ex"])

      assert File.exists?(helpers_path),
             "expected generated model_helpers.ex at #{helpers_path}"
    end

    test "generated model aliases the LOCAL ModelHelpers, not Portico's", %{
      temp_dir: temp_dir,
      dir_name: dir_name,
      module_name: module_name
    } do
      user_source = File.read!(Path.join([temp_dir, "lib", dir_name, "models", "user.ex"]))

      # The generated code must reference the local namespace so consumers
      # don't need to carry Portico as a runtime dependency.
      assert user_source =~ "alias #{module_name}.ModelHelpers"
      refute user_source =~ "Portico.Runtime.ModelHelpers"
    end

    test "no generated file references the Portico module namespace at code level", %{
      temp_dir: temp_dir,
      dir_name: dir_name
    } do
      # Match `Portico.<SomeModule>` — an actual code-level module reference
      # — rather than the bare word "Portico" (which is allowed in docstring
      # prose that explains the decoupling).
      offending =
        temp_dir
        |> Path.join("lib/#{dir_name}/**/*.ex")
        |> Path.wildcard()
        |> Enum.filter(fn file ->
          source = File.read!(file)

          Enum.any?(code_lines(source), fn line ->
            line =~ ~r/\bPortico\.[A-Z]/
          end)
        end)

      assert offending == [],
             "generated files must not reference Portico at runtime; offenders: #{inspect(offending)}"
    end

    # Strip out @moduledoc / @doc blocks and line comments so the Portico
    # check looks only at real code.
    defp code_lines(source) do
      source
      |> String.replace(~r/@(moduledoc|doc|typedoc)\s+"""[\s\S]*?"""/m, "")
      |> String.split("\n")
      |> Enum.reject(&(&1 |> String.trim() |> String.starts_with?("#")))
    end

    test "generated ModelHelpers is standalone (compiles and is usable)", %{
      module_name: module_name
    } do
      # If we got here, setup_all already compiled User, which required the
      # helpers module to be loaded — so its existence is implicit. But we
      # still want to verify the namespace is correct and the expected API
      # is present.
      helpers_module = Module.concat(module_name, "ModelHelpers")

      assert function_exported?(helpers_module, :normalize_params, 1)
      assert function_exported?(helpers_module, :normalize_params, 2)
      assert function_exported?(helpers_module, :struct_to_json, 1)
      assert function_exported?(helpers_module, :struct_to_json, 2)
      assert function_exported?(helpers_module, :apply_changeset_permissively, 1)
      assert function_exported?(helpers_module, :serialize_value, 1)
    end
  end
end
