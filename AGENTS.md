# Agent Guidelines

## Development

```sh
mix deps.get
mix ci
```

## Conventions

- Use the project Mix aliases; prefer `mix ci` for the full validation suite.
- GitHub CI uses the shared `elixir-vibe/actions/.github/workflows/elixir-rustler-ci.yml` workflow for Rustler setup and Cargo caching.
- Keep changes small, tested, and formatted.
- For generated native drawing code, follow `docs/codegen.md`: keep Skia semantics in Rusty Elixir modules under `Skia.Codegen.Rusty`, keep `Skia.Codegen` orchestration-only, and avoid raw Rust/body-string workarounds.
