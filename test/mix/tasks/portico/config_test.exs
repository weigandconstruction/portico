defmodule Mix.Tasks.Portico.ConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @test_spec_with_servers %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "Test API with Servers",
      "version" => "1.0.0"
    },
    "servers" => [
      %{"url" => "https://api.example.com"},
      %{"url" => "https://staging.example.com"}
    ],
    "paths" => %{
      "/users" => %{
        "get" => %{
          "summary" => "List users",
          "tags" => ["users"],
          "responses" => %{
            "200" => %{"description" => "Success"}
          }
        }
      },
      "/posts" => %{
        "get" => %{
          "summary" => "List posts",
          "tags" => ["posts", "content"],
          "responses" => %{
            "200" => %{"description" => "Success"}
          }
        }
      }
    }
  }

  @test_spec_without_servers %{
    "openapi" => "3.0.0",
    "info" => %{
      "title" => "Test API without Servers",
      "version" => "1.0.0"
    },
    "paths" => %{
      "/items" => %{
        "get" => %{
          "summary" => "List items",
          "tags" => ["items"],
          "responses" => %{
            "200" => %{"description" => "Success"}
          }
        }
      }
    }
  }

  setup do
    # Create a temporary directory for testing
    {:ok, temp_dir} = Briefly.create(type: :directory)
    %{temp_dir: temp_dir}
  end

  describe "run/1" do
    test "requires --spec argument" do
      assert_raise RuntimeError,
                   "You must provide a spec using --spec",
                   fn ->
                     Mix.Tasks.Portico.Config.run([])
                   end
    end

    test "generates config with servers", %{temp_dir: temp_dir} do
      spec_file = Path.join(temp_dir, "spec_with_servers.json")
      File.write!(spec_file, Jason.encode!(@test_spec_with_servers))
      config_file = Path.join(temp_dir, "portico.config.json")

      File.cd!(temp_dir, fn ->
        output =
          capture_io(fn ->
            Mix.Tasks.Portico.Config.run(["--spec", spec_file])
          end)

        assert output =~ "Configuration file generated: portico.config.json"
        assert output =~ "Found 3 unique tags"
        assert output =~ "Generated module name: TestApiWithServers"

        # Read and verify the generated config
        assert File.exists?(config_file)
        config = Jason.decode!(File.read!(config_file))

        # Check spec_info
        assert config["spec_info"]["source"] == spec_file
        assert config["spec_info"]["title"] == "Test API with Servers"
        assert config["spec_info"]["module"] == "TestApiWithServers"

        # Check base_url
        assert config["base_url"] == "https://api.example.com"

        # Check tags
        assert config["tags"] == ["content", "posts", "users"]
      end)
    end

    test "generates config without servers", %{temp_dir: temp_dir} do
      spec_file = Path.join(temp_dir, "spec_without_servers.json")
      File.write!(spec_file, Jason.encode!(@test_spec_without_servers))
      config_file = Path.join(temp_dir, "portico.config.json")

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Config.run(["--spec", spec_file])
        end)

        # Read and verify the generated config
        assert File.exists?(config_file)
        config = Jason.decode!(File.read!(config_file))

        # Check base_url is nil when no servers are defined
        assert config["base_url"] == nil

        # Other fields should still be present
        assert config["spec_info"]["title"] == "Test API without Servers"
        assert config["tags"] == ["items"]
      end)
    end

    test "custom output file", %{temp_dir: temp_dir} do
      spec_file = Path.join(temp_dir, "spec.json")
      File.write!(spec_file, Jason.encode!(@test_spec_with_servers))
      custom_config = Path.join(temp_dir, "my-custom-config.json")

      File.cd!(temp_dir, fn ->
        output =
          capture_io(fn ->
            Mix.Tasks.Portico.Config.run([
              "--spec",
              spec_file,
              "--output",
              "my-custom-config.json"
            ])
          end)

        assert output =~ "Configuration file generated: my-custom-config.json"
        assert File.exists?(custom_config)

        # Default file should not be created
        refute File.exists?("portico.config.json")
      end)
    end

    test "handles empty servers array", %{temp_dir: temp_dir} do
      spec_with_empty_servers = Map.put(@test_spec_without_servers, "servers", [])
      spec_file = Path.join(temp_dir, "spec_empty_servers.json")
      File.write!(spec_file, Jason.encode!(spec_with_empty_servers))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Config.run(["--spec", spec_file])
        end)

        config = Jason.decode!(File.read!("portico.config.json"))
        assert config["base_url"] == nil
      end)
    end

    test "handles servers with different formats", %{temp_dir: temp_dir} do
      spec_with_varied_servers = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "servers" => [
          %{"url" => "https://api.example.com/v1"},
          %{"url" => "/api/v2", "description" => "Relative URL"}
        ],
        "paths" => %{}
      }

      spec_file = Path.join(temp_dir, "spec_varied_servers.json")
      File.write!(spec_file, Jason.encode!(spec_with_varied_servers))

      File.cd!(temp_dir, fn ->
        capture_io(fn ->
          Mix.Tasks.Portico.Config.run(["--spec", spec_file])
        end)

        config = Jason.decode!(File.read!("portico.config.json"))
        # Should use the first server URL regardless of format
        assert config["base_url"] == "https://api.example.com/v1"
      end)
    end
  end

  describe "module name generation" do
    test "handles various title formats", %{temp_dir: temp_dir} do
      test_cases = [
        {"Simple API", "SimpleApi"},
        {"my-dashed-api", "MyDashedApi"},
        {"API_with_underscores", "ApiWithUnderscores"},
        {"API v2.0 (Beta)", "ApiV20Beta"},
        {"123 Numbers First", "123NumbersFirst"},
        {"   Spaces   Everywhere   ", "SpacesEverywhere"}
      ]

      for {title, expected_module} <- test_cases do
        spec = %{
          "openapi" => "3.0.0",
          "info" => %{"title" => title, "version" => "1.0"},
          "paths" => %{}
        }

        spec_file = Path.join(temp_dir, "spec_#{expected_module}.json")
        File.write!(spec_file, Jason.encode!(spec))

        File.cd!(temp_dir, fn ->
          capture_io(fn ->
            Mix.Tasks.Portico.Config.run(["--spec", spec_file])
          end)

          config = Jason.decode!(File.read!("portico.config.json"))
          assert config["spec_info"]["module"] == expected_module
        end)
      end
    end
  end
end
