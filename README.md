# Portico – Elixir OpenAPI 3.0 Generator

[![CI](https://github.com/weigandconstruction/portico/actions/workflows/ci.yml/badge.svg)](https://github.com/weigandconstruction/portico/actions/workflows/ci.yml)

> ⚠️ **WARNING: DEVELOPMENT VERSION** ⚠️
>
> This project is currently in very early development and **NOT READY FOR PRODUCTION USE**.
> APIs, data structures, and functionality may change significantly without notice.
> Some things will just flat out not work.
> Use at your own risk and expect breaking changes.

**Portico** is an Elixir library that generates HTTP API clients directly into your project from OpenAPI 3.0 specifications.

## 🎯 Why Portico?

This project was inspired by [this Dashbit blog post](https://dashbit.co/blog/sdks-with-req-stripe). As outlined in the
post, there are some valid concerns with API clients in general:

- **Bloat**: SDKs usually include the entire API surface area and can be quite large leading to slow compile times
- **Complexity**: They are either hand-crafted or generated from tools like [OpenAPI
  Generator](https://github.com/OpenAPITools/openapi-generator). If an SDK is not available, either of these options has
  a high level of complexity.
- **Opaque**: "What do we do when things go wrong?" With code hidden in external dependencies we become dependent on
  this code being correct and maintained.

The article proposes we craft small, simple clients. This is excellent advice, but what if we need more than just a few
API calls or have a larger number of services?

Portico solves this by giving you a lightweight, simple, and transparent solution, without requiring you to build your own
clients. We do this by leveraging the OpenAPI 3.0 spec, Req, and code generation. With Portico you can achieve the same
results without the extra work.

## 🚀 Features

- **Lightweight**: Very minimal implementation on top of the `Req` HTTP client, no other dependencies
- **Code Generation**: Creates client code in your project that you can edit or remove
- **OpenAPI 3.0 Support**: Parse and generate clients from OpenAPI 3.0 specifications in JSON or YAML format
- **Operation Filtering**: Generate only the operations you need by filtering by tags
- **Type Documentation**: Generate documentation for all parameters and operations
- **Typespec Generation**: Elixir typespecs for all generated functions

## 📋 Requirements

- Elixir 1.15 or later
- OpenAPI 3.0 specification in JSON or YAML format

### Supported Versions

Portico is continuously tested against:

- **Elixir**: 1.15, 1.16, 1.17, 1.18
- **OTP**: 24, 25, 26, 27 (compatible combinations)

## 🛠 Installation

Add `portico` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:portico, github: "weigandconstruction/portico", only: :dev},
    {:req, "~> 0.5"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## 🎯 Quick Start

### 1. Generate a Configuration

First, generate a configuration file for your OpenAPI specification:

```bash
# Generate config with default name (portico.config.json)
mix portico.config --spec https://api.example.com/openapi.json

# Generate config from a local spec file
mix portico.config --spec openapi.yaml

# Generate config with custom name
mix portico.config --spec openapi.yaml --output my-api.config.json
```

This generates a config file containing:

- **spec_info**: Metadata about the API specification
- **base_url**: The default server URL from the OpenAPI spec (if available)
- **tags**: All available tags from the specification

```json
{
  "spec_info": {
    "source": "https://api.example.com/openapi.json",
    "title": "My API",
    "module": "ServiceName.API"
  },
  "base_url": "https://api.example.com",
  "tags": ["users", "orders", "products", "authentication"]
}
```

You can edit this file and commit it to version control.

When running `mix portico.generate --config` with a config file, Portico will:

- Use the module name as the base module (and path) for the generated client (e.g. `ServiceName.API` will generate
  the client code in `lib/service_name/api/*` with namespace `ServiceName.API.*`)
- Only generate operations that include the listed tags
- Use the `base_url` as the default for the generated client (can be overridden at runtime)

### 2. Generate an API Client

Generate a client with a specified configuration:

```bash
mix portico.generate --config path/to/config.json
```

You can also use the generator without a configuration by providing extra flags:

```bash
mix portico.generate --module MyAPI --spec path/to/openapi.json

# Specify a tag
mix portico.generate --module MyAPI --spec path/to/openapi.yaml --tag users
```

Note, some features like default `base_url` require use of a config file. It is recommended that you use a config.

### 3. Use Your Generated Client

The generated client supports flexible configuration with automatic base URL detection from your OpenAPI spec.

```elixir
# When generated from a config with base_url, the URL is optional
client = MyAPI.Client.new()
client = MyAPI.Client.new(auth: {:bearer, "your-token"})

# Override the base URL for different environments
staging = MyAPI.Client.new(base_url: "https://staging.example.com", auth: {:bearer, "staging-token"})
prod = MyAPI.Client.new(base_url: "https://api.example.com", auth: {:bearer, "prod-token"})

# When generated without a base_url, you must provide it
client = MyAPI.Client.new(base_url: "https://api.example.com", auth: {:bearer, "your-token"})

# Make API calls using generated modules
case MyAPI.Users.get_user(client, "user123") do
  {:ok, user} -> IO.inspect(user)
  {:error, exception} -> IO.puts("Error: #{exception.message}")
end

# All Req options are supported
client = MyAPI.Client.new(
  auth: {:bearer, "token"},
  timeout: 30_000,
  retry: :transient,
  plug: {MyApp.RequestLogger, []}
)
```

### Application Configuration

You can optionally set default client options in your application config. This is especially useful for testing with mocks:

```elixir
# config/test.exs
config :my_api,
  client: [
    plug: {Req.Test, MyApp.MockServer}
  ]

# config/dev.exs
config :my_api,
  client: [
    retry: false,
    cache: true,
    pool_timeout: 5000
  ]

# Options from config are automatically merged with options passed to new/1
# (provided options take precedence)
client = MyAPI.Client.new(auth: {:bearer, "token"})
```
