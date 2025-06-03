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

# Generate API client from OpenAPI spec
mix hydra.generate --module MyAPI --spec https://api.example.com/openapi.json
mix hydra.generate --module MyAPI --spec path/to/spec.json

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

Generated modules expect configuration in `config.exs`:
```elixir
config :hydra, YourAPI,
  base_url: "https://api.example.com",
  auth: {:bearer, "token"}
```