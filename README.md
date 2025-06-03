# Hydra – Elixir OpenAPI 3.0 Generator

> ⚠️ **WARNING: DEVELOPMENT VERSION** ⚠️
>
> This project is currently in very early development and **NOT READY FOR PRODUCTION USE**.
> APIs, data structures, and functionality may change significantly without notice.
> Some things will just flat out not work.
> Use at your own risk and expect breaking changes.

**Hydra** is an Elixir library that generates HTTP API clients directly into your project from OpenAPI 3.0 specifications. Instead of searching for existing SDKs or building API clients from scratch, Hydra creates tailored client code that becomes part of your codebase. This approach gives you complete control over the generated code and allows you to generate only the API operations you actually need (filtering capabilities coming soon).

## 🎯 Why Hydra?

Finding or building API clients for external services is time-consuming and often results in either:

- Bloated SDKs with hundreds of methods you don't need leading to slow compiles
- Outdated or unmaintained third-party libraries
- Custom HTTP client code that's tedious to write and maintain as APIs change

Hydra generates lean, focused API clients directly in your project from OpenAPI specs. You get:

- **Minimal External Dependencies**: Generated code becomes part of your codebase (We do, however, depend on Req)
- **Complete Control**: Modify, extend, or customize the generated code as needed
- **Selective Generation**: Include only the API operations you actually use (coming soon)
- **Always Up-to-Date**: Easily regenerate when the OpenAPI Spec changes

## 🚀 Features

- **Direct Code Generation**: Creates client code in your project, not as an external dependency
- **OpenAPI 3.0 Support**: Parse and generate clients from OpenAPI 3.0 JSON specifications
- **Tag-based Module Organization**: Groups API operations by OpenAPI tags for better code organization
- **Selective Operation Support**: Generate only the endpoints you need (filtering TBD)
- **Automatic Parameter Handling**: Supports path, query, header, and request body parameters
- **Type Documentation**: Generates comprehensive documentation for all parameters and operations
- **HTTP Client Integration**: Built on top of the reliable `Req` HTTP client
- **Mix Task Integration**: Simple command-line interface for code generation

## 📋 Requirements

- Elixir 1.18 or later (will eventually relax this)
- OpenAPI 3.0 specification in JSON format (incomplete support at this time)

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

### 1. Generate an API Client

Generate client code directly into your project from a remote OpenAPI specification:

```bash
mix hydra.generate --module MyAPI --spec https://api.example.com/openapi.json
```

Or from a local file:

```bash
mix hydra.generate --module MyAPI --spec path/to/openapi.json
```

This creates Elixir modules in your `lib/` directory - the code becomes part of your project.

### 2. Configure Your Client

Add client configuration to your `config/config.exs`:

```elixir
config :hydra, MyAPI,
  base_url: "https://api.example.com",
  auth: {:bearer, "your-api-token"}
```

Note: configurable auth is something we're working on.

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

**This code is yours** - you can modify it, extend it, or customize it however you need. It's not hidden inside a
dependency.

### Module Organization

- **Tag-based Grouping**: Operations are grouped by their first OpenAPI tag
- **Fallback Naming**: Operations without tags use path-based module names
- **Unique Function Names**: Function names combine HTTP method with path segments

### Documentation Generation

All generated functions include comprehensive documentation from the OpenAPI spec:

```elixir
@doc """
Get user by ID

Returns detailed information about a specific user.

## Parameters

- `user_id` - `string` (required) - Unique identifier for the user
- `fields` - `string` (optional) - Comma-separated list of fields to return

"""
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
