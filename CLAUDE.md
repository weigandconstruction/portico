# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hydra is an Elixir library for generating API clients from OpenAPI 3.0 specifications. It parses OpenAPI specs (JSON format) and generates structured Elixir modules with HTTP client functions.

## Core Architecture

- **Hydra**: Main entry point that parses specs from URLs or files using `Req` for HTTP requests
- **Hydra.Spec**: Core data structures representing OpenAPI specs with typed structs for specs, paths, operations, parameters, and responses
- **Mix.Tasks.Hydra.Generate**: Mix task that generates API client code from specs
- **Templates**: EEx templates in `priv/templates/` for generating client and API modules

The generation flow: OpenAPI JSON → parsed into Hydra.Spec structs → processed through EEx templates → generated Elixir client modules.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests
mix test

# Generate configuration file from OpenAPI spec
mix hydra.config --spec https://api.example.com/openapi.json
mix hydra.config --spec path/to/spec.json --output my-config.json

# Generate API client from OpenAPI spec
mix hydra.generate --module MyAPI --spec https://api.example.com/openapi.json
mix hydra.generate --module MyAPI --spec path/to/spec.json

# Generate API client with tag filtering
mix hydra.generate --module MyAPI --spec spec.json --tag users
mix hydra.generate --module MyAPI --spec spec.json --config my-config.json

# Run specific test file
mix test test/hydra_test.exs

# Interactive shell with project loaded
iex -S mix
```

## Code Generation

Generated clients include:

- Base client module with HTTP configuration (`Client` module)
- API modules for each path with HTTP methods as functions
- Automatic parameter handling (path, query, header parameters)
- Integration with `Req` HTTP client

### Usage Example

```elixir
# Create client with authentication
client = MyAPI.Client.new("https://api.example.com", auth: {:bearer, "your-token"})

# Make API calls (returns {:ok, response} or {:error, exception})
{:ok, users} = MyAPI.Users.list_users(client)
{:ok, post} = MyAPI.Posts.create_post(client, %{title: "Hello", body: "World"})

# Different environments
staging_client = MyAPI.Client.new("https://staging.example.com", auth: {:bearer, "staging-token"})
prod_client = MyAPI.Client.new("https://api.example.com", auth: {:bearer, "prod-token"})

# With additional options
client = MyAPI.Client.new("https://api.example.com", [
  auth: {:bearer, "token"},
  timeout: 30_000,
  retry: :transient
])
```

## Workflow Reminders

- When done making changes, run tests to confirm everything is working
- Don't forget to run `mix format` after finishing code generation
- Don't forget to run `mix credo` after finishing code generation and fix any issues
