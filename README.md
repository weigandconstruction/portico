# Hydra – Elixir OpenAPI 3.0 Generator

[![CI](https://github.com/weigandconstruction/hydra/actions/workflows/ci.yml/badge.svg)](https://github.com/weigandconstruction/hydra/actions/workflows/ci.yml)

> ⚠️ **WARNING: DEVELOPMENT VERSION** ⚠️
>
> This project is currently in very early development and **NOT READY FOR PRODUCTION USE**.
> APIs, data structures, and functionality may change significantly without notice.
> Some things will just flat out not work.
> Use at your own risk and expect breaking changes.

**Hydra** is an Elixir library that generates HTTP API clients directly into your project from OpenAPI 3.0 specifications.

## 🎯 Why Hydra?

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

Hydra solves this by giving you a lightweight, simple, and transparent solution, without requiring you to build your own
clients. We do this by leveraging the OpenAPI 3.0 spec, Req, and code generation. With Hydra you can achieve the same
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

### 1. Generate a Configuration

First, generate a configuration showing the tags available in your OpenAPI specification:

```bash
# Generate config with default name (hydra.config.json)
mix hydra.config --spec https://api.example.com/openapi.json

# Generate config from a local spec file
mix hydra.config --spec openapi.yaml

# Generate config with custom name
mix hydra.config --spec openapi.yaml --output my-api.config.json
```

This generates a config file containing all available tags:

```json
{
  "spec_info": {
    "source": "https://api.example.com/openapi.json",
    "title": "My API",
    "module": "ServiceName.API"
  },
  "tags": ["users", "orders", "products", "authentication"]
}
```

You can curate the list of tags to only those you need. When running `mix hydra.generate --config` with a config file, Hydra will only generate
operations that include these tags.

### 2. Generate an API Client

Generate a client with a specified configuration:

```bash
mix hydra.generate --config path/to/config.json
```

You can also use the generator without a configuration by providing extra flags:

```bash
mix hydra.generate --module MyAPI --spec path/to/openapi.json

# Specify a tag
mix hydra.generate --module MyAPI --spec path/to/openapi.yaml --tag users
```

This creates Elixir modules in your `lib/` directory. You can nest it in your application by providing the full module
namespace – e.g. `MyApp.ServiceName.API`.

### 3. Use Your Generated Client

Authentication and usage will vary by API. A simple bearer token authentication may be used as shown below.

```elixir
# Create client with bearer token authentication (note, the provided options are just Req options)
client = MyAPI.Client.new("https://api.example.com", auth: {:bearer, "your-token"})

# Make an API call using generated module
case MyAPI.Users.get_user(client, "user123") do
  {:ok, user} -> IO.inspect(user)
  {:error, exception} -> IO.puts("Error: #{exception.message}")
end
```
