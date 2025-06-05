# Hydra – Elixir OpenAPI 3.0 Generator

[![CI](https://github.com/weigandconstruction/hydra/actions/workflows/ci.yml/badge.svg)](https://github.com/weigandconstruction/hydra/actions/workflows/ci.yml)

> ⚠️ **WARNING: DEVELOPMENT VERSION** ⚠️
>
> This project is currently in very early development and **NOT READY FOR PRODUCTION USE**.
> APIs, data structures, and functionality may change significantly without notice.
> Some things will just flat out not work.
> Use at your own risk and expect breaking changes.

**Hydra** is an Elixir library that generates HTTP API clients directly into your project from OpenAPI 3.0 specifications. Instead of searching for existing SDKs or building API clients from scratch, Hydra generates client code that becomes part of your codebase. This approach gives you complete control and allows you to generate only the API operations you actually need (filtering capabilities coming soon).

## 🎯 Why Hydra?

Hydra helps you avoid:

- Bloated SDKs with hundreds of methods you don't need leading to slow compiles
- Outdated or unmaintained third-party libraries
- Custom HTTP client code that's tedious to write and maintain as APIs change

Hydra generates minimal API clients directly in your project from OpenAPI specs. You get:

- **Minimal External Dependencies**: Generated code becomes part of your codebase
- **Complete Control**: Modify, extend, or customize the generated code as needed
- **Selective Generation**: Generate only the API operations you actually use
- **Always Up-to-Date**: Easily regenerate your client code when the OpenAPI Spec changes

## 🚀 Features

- **Lightweight**: Very minimal implementation on top of the `Req` HTTP client
- **Code Generation**: Creates client code in your project, not as an external dependency
- **OpenAPI 3.0 Support**: Parse and generate clients from OpenAPI 3.0 specifications in JSON or YAML format
- **Tag-based Module Organization**: Groups API operations by OpenAPI tags, falling back to path-based grouping
- **Operation Filtering**: Generate only the operations you need using OpenAPI tags
- **Type Documentation**: Generates comprehensive documentation for all parameters and operations
- **Typespec Generation**: Elixir typespecs for all generated functions with proper parameter types

## 📋 Requirements

- Elixir 1.15 or later
- OpenAPI 3.0 specification in JSON or YAML format

### Supported Versions

Hydra is continuously tested against:

- **Elixir**: 1.15, 1.16, 1.17, 1.18
- **OTP**: 24, 25, 26, 27 (compatible combinations)

## 🛠 Installation

Add `hydra` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hydra, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## 🎯 Quick Start

### 1. Discover Available API Operations

First, generate a configuration showing the tags available in your OpenAPI specification:

```bash
# Generate config with default name (hydra.config.json)
mix hydra.config --spec https://api.example.com/openapi.json

# Generate config with custom name
mix hydra.config --spec https://api.example.com/openapi.json --output my-api.config.json
```

This generates a config file containing all available tags:

```json
{
  "tags": ["users", "orders", "products", "authentication"],
  "spec_info": {
    "title": "My API",
    "version": "1.0.0"
  }
}
```

You can curate the list of tags to only those you need. When generating with a config file, Hydra will only generate
operations that include tags in this list.

### 2. Generate an API Client

Generate client code directly into your project from a remote OpenAPI specification:

```bash
# Generate all API operations
mix hydra.generate --module MyAPI --spec https://api.example.com/openapi.json

# Generate operations for a specific tag
mix hydra.generate --module MyAPI --spec spec.json --tag users

# Generate all tags present in a config file
mix hydra.generate --module MyAPI --spec spec.json --config hydra.config.json
```

Or from a local file:

```bash
# From JSON file
mix hydra.generate --module MyAPI --spec path/to/openapi.json

# From YAML file
mix hydra.generate --module MyAPI --spec path/to/openapi.yaml
```

This creates Elixir modules in your `lib/` directory - the code becomes part of your project.

### 3. Use Your Generated Client

Create a client instance with authentication and make requests:

```elixir
# Create client with bearer token authentication
client = MyAPI.Client.new("https://api.example.com", auth: {:bearer, "your-token"})

# Make an API call using generated module
case MyAPI.Users.get_user(client, "user123") do
  {:ok, response} -> IO.inspect(response.body)
  {:error, exception} -> IO.puts("Error: #{exception.message}")
end
```

## 📁 Generated Code Structure

Hydra generates client code directly in your project's `lib/` directory:

```
lib/
├── my_api/
│   ├── client.ex          # HTTP client configuration
│   └── api/
│       ├── users.ex       # User management operations
│       ├── orders.ex      # Order operations
│       └── products.ex    # Product operations
```

**This code is yours** - you can modify it, extend it, or customize it however you need.

### Module Organization

- **Tag-based Grouping**: Operations are grouped by their first OpenAPI tag
- **Fallback Naming**: Operations without tags use path-based module names
- **Unique Function Names**: Function names combine HTTP method with path segments

### Documentation and Type Safety

All generated functions include documentation and typespecs from the OpenAPI spec:

```elixir
@doc """
Get user by ID

Returns detailed information about a specific user.

## Parameters

- `client` - HTTP client instance (required)
- `user_id` - `string` (required) - Unique identifier for the user
- `opts` - `keyword` (optional) - Optional parameters as keyword list
  - `fields` - `string` (optional) - Comma-separated list of fields to return

"""
@spec get_user(Req.Request.t(), String.t(), keyword()) :: {:ok, any()} | {:error, Exception.t()}
def get_user(client, user_id, opts \\ []) do
  # Generated implementation...
end
```

## 🤝 Contributing

As this is a development version, contributions are welcome but please note:

1. **Breaking Changes**: Expect frequent breaking changes
2. **API Stability**: No API stability guarantees
3. **Testing**: All contributions should include tests
4. **Documentation**: Update documentation for new features

## 🔗 Related Projects

- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Req HTTP Client](https://github.com/wojtekmach/req)
- [ExDoc Documentation](https://github.com/elixir-lang/ex_doc)

---

> 🚧 **Remember**: This is a development version. Use in production at your own risk!
