defmodule Hydra.AuthTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Client generation" do
    test "generates client with new function and request method" do
      # Create test spec with auth endpoint
      spec = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test API", "version" => "1.0.0"},
        "paths" => %{
          "/users" => %{
            "get" => %{
              "summary" => "Get users",
              "operationId" => "getUsers",
              "responses" => %{
                "200" => %{"description" => "Success"}
              }
            }
          }
        }
      }

      # Generate code with auth support
      module_name = TestAPI
      output_path = Path.join(System.tmp_dir(), "test_auth_#{:rand.uniform(1000)}")
      spec_path = Path.join(System.tmp_dir(), "test_spec_#{:rand.uniform(1000)}.json")
      File.mkdir_p!(output_path)
      File.write!(spec_path, Jason.encode!(spec))

      try do
        File.cd!(output_path, fn ->
          capture_io(fn ->
            Mix.Tasks.Hydra.Generate.run([
              "--module",
              to_string(module_name),
              "--spec",
              spec_path
            ])
          end)

          # Check that client template generates auth functions
          client_file = "lib/elixir/test_api/client.ex"
          assert File.exists?(client_file)

          client_content = File.read!(client_file)

          # Verify client functions are present
          assert client_content =~ "def new(base_url, options \\\\ [])"
          assert client_content =~ "def request(client, options \\\\ [])"

          # Verify function signature includes client parameter
          users_file = "lib/elixir/test_api/api/users.ex"
          assert File.exists?(users_file)

          users_content = File.read!(users_file)
          assert users_content =~ "def get_users(client)"
          assert users_content =~ "TestAPI.Client.request(client,"
        end)
      after
        File.rm_rf!(output_path)
        File.rm_rf!(spec_path)
      end
    end
  end
end
