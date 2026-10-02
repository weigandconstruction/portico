defmodule PorticoTest do
  use ExUnit.Case
  doctest Portico

  setup do
    {:ok, dir} = Briefly.create(type: :directory)
    %{dir: dir}
  end

  defp write!(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)
    path
  end

  describe "parse!/1" do
    test "parses an OpenAPI 3 spec", %{dir: dir} do
      path = write!(dir, "spec.json", ~s({"openapi": "3.1.0", "info": {}, "paths": {}}))
      assert %Portico.Spec{version: "3.1.0", paths: []} = Portico.parse!(path)
    end

    test "rejects content that isn't a spec, like a 404 page parsed as YAML", %{dir: dir} do
      path = write!(dir, "spec.yaml", "404: Not Found")

      assert_raise RuntimeError, ~r/doesn't look like an OpenAPI spec.*Not Found/, fn ->
        Portico.parse!(path)
      end
    end

    test "rejects Swagger 2.0", %{dir: dir} do
      path = write!(dir, "spec.json", ~s({"swagger": "2.0", "paths": {}}))

      assert_raise RuntimeError, ~r/Swagger 2.0 specs aren't supported/, fn ->
        Portico.parse!(path)
      end
    end

    test "rejects other OpenAPI versions", %{dir: dir} do
      path = write!(dir, "spec.json", ~s({"openapi": "4.0.0", "paths": {}}))
      assert_raise RuntimeError, ~r/Only OpenAPI 3 specs/, fn -> Portico.parse!(path) end
    end

    test "rejects a spec with no paths", %{dir: dir} do
      path = write!(dir, "spec.json", ~s({"openapi": "3.0.0", "info": {}}))
      assert_raise RuntimeError, ~r/no paths/, fn -> Portico.parse!(path) end
    end
  end

  describe "Fetch.fetch/2" do
    defp respond(status, body, headers \\ []) do
      fn request ->
        response = Req.Response.new(status: status, body: body)

        {request,
         Enum.reduce(headers, response, fn {k, v}, r -> Req.Response.put_header(r, k, v) end)}
      end
    end

    test "raises on a non-2xx status" do
      assert_raise RuntimeError,
                   ~r{Could not fetch the spec from https://x.test/spec: HTTP 404},
                   fn ->
                     Portico.Fetch.fetch("https://x.test/spec",
                       adapter: respond(404, "404: Not Found")
                     )
                   end
    end

    test "detects the content type from the header or the body" do
      yaml = "openapi: 3.0.0"

      assert {^yaml, :yaml} =
               Portico.Fetch.fetch("https://x.test/spec",
                 adapter: respond(200, yaml, [{"content-type", "application/yaml"}])
               )

      assert {_, :json} = Portico.Fetch.fetch("https://x.test/spec", adapter: respond(200, "{}"))
    end
  end
end
