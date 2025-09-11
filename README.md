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
- **Model Generation**: Automatically generates Ecto-based models from OpenAPI schemas with type casting and JSON conversion

## 📋 Requirements

- Elixir 1.15 or later
- OpenAPI 3.0 specification in JSON or YAML format
- Ecto ~> 3.11 (optional, only required when generating models)

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

If you want to generate models (recommended), also add Ecto:

```elixir
def deps do
  [
    {:portico, github: "weigandconstruction/portico", only: :dev},
    {:req, "~> 0.5"},
    {:ecto, "~> 3.11"}  # Optional: only needed if generating models
  ]
end
```

Then run:

```bash
mix deps.get
```

**Note:** Ecto is an optional dependency. It's only required if you plan to generate models from your OpenAPI schemas (which is the default behavior). If you use the `--no-models` flag when generating, Ecto is not needed.

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

# Disable model generation (models are generated by default)
mix portico.generate --config path/to/config.json --no-models
```

Note, some features like default `base_url` require use of a config file. It is recommended that you use a config.

#### Model Generation

By default, Portico generates Ecto-based models for all schemas defined in your OpenAPI spec. These models:
- Are created in a `models/` subdirectory within your generated API module
- Use Ecto embedded schemas for clean type casting without database persistence
- Include typespecs for all fields
- Provide `from_json/1` and `to_json/1` functions for JSON conversion
- Automatically handle type conversions (dates, datetimes, decimals, etc.)
- Support both component schemas (`components.schemas`) and inline schemas in responses/requests
- Treat inline objects as `:map` fields for flexibility

**Important:** Model generation requires Ecto as a dependency. If you don't have Ecto installed, either:
- Add `{:ecto, "~> 3.11"}` to your dependencies, or
- Use the `--no-models` flag when generating to skip model generation

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

### Working with Generated Models

When models are generated (default behavior), API responses are automatically converted to Ecto-powered structs with proper type casting. No manual JSON conversion needed!

```elixir
# API calls automatically return typed model structs
{:ok, %MyAPI.Models.User{} = user} = MyAPI.Users.get_user(client, "123")

# Type casting happens automatically:
# - Dates/times are parsed to DateTime structs
# - Numbers are converted to integers/decimals
# - Nested objects with $ref become embedded structs
# - Inline objects (without $ref) remain as maps
IO.puts("User: #{user.name}")
IO.puts("Created: #{user.created_at}")  # DateTime struct, not a string!
IO.puts("Score: #{user.score}")         # Decimal struct
IO.puts("Active: #{user.is_active}")    # Boolean

# Arrays of models work seamlessly
{:ok, users} = MyAPI.Users.list_users(client)
Enum.each(users, fn %MyAPI.Models.User{} = user ->
  IO.puts("#{user.name}: created #{user.created_at}")
end)

# For requests, just pass regular maps - no conversion needed!
{:ok, updated} = MyAPI.Users.update_user(client, "123", %{
  name: "New Name",
  email: "new@example.com"
})

# Or work with structs directly if you prefer
updated_user = %{user | name: "Updated Name"}
{:ok, result} = MyAPI.Users.update_user(client, "123", Map.from_struct(updated_user))

# Pattern matching with typed structs
case MyAPI.Users.get_user(client, user_id) do
  {:ok, %MyAPI.Models.User{status: "active"} = user} ->
    process_active_user(user)
  {:ok, %MyAPI.Models.User{status: status}} ->
    IO.puts("User is #{status}")
  {:error, exception} ->
    handle_error(exception)
end

# Models include typespecs for better IDE support
@spec welcome_user(MyAPI.Models.User.t()) :: String.t()
def welcome_user(%MyAPI.Models.User{name: name}), do: "Welcome, #{name}!"
```

#### Manual JSON Conversion (Rarely Needed)

While automatic conversion handles most cases, the models do provide `from_json/1` and `to_json/1` functions if you ever need manual control:

```elixir
# Manual conversion from JSON (usually not needed)
json_data = %{"name" => "Jane", "created_at" => "2024-01-15T10:30:00Z"}
user = MyAPI.Models.User.from_json(json_data)

# Manual conversion to JSON (usually not needed)
json = MyAPI.Models.User.to_json(user)
```

### Application Configuration

You can optionally set default client options in your application config. This is especially useful for testing with mocks:

```elixir
# config/test.exs
config :my_app,
  my_api: [
    plug: {Req.Test, MyApp.MockServer}
  ]

# config/dev.exs
config :my_app,
  my_api: [
    retry: false,
    cache: true,
    pool_timeout: 5000
  ]

# Options from config are automatically merged with options passed to new/1
# (provided options take precedence)
client = MyAPI.Client.new(auth: {:bearer, "token"})
```
