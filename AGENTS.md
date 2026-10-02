# AGENTS

This repo is an Elixir library that wraps SPICE and ERFA via NIFs.
Use this file to understand the local workflow and style.

## Project Map

- Elixir source: `lib/`
- Tests: `test/`
- NIF C sources: `c_src/`

## Build / Lint / Test Commands

### Setup

- Fetch deps: `mix deps.get`
- Compile (runs elixir_make + Makefile): `mix compile`
- Clean build artifacts: `mix clean`

### Lint / Static Checks

- Full check suite (compiler, formatter, unused_deps, credo, markdown, tests): `mix check`
- Fix checks where supported: `mix check --fix`

### Tests

- All tests: `mix test`
- Single test file: `mix test test/astro/orbit_test.exs`
- Single test by line: `mix test test/astro/orbit_test.exs:41`
- Tagged tests: `mix test --only <tag>`
- Trace output: `mix test --trace`
- Without downloaded kernels: `mix test --exclude kernels`

Tests tagged `:kernels` read catalog kernels from `priv/kernels/` (download them
with `mix astro.kernels`); untagged tests use only `test/fixtures/`. Tag every
new test that needs a catalog kernel. `test/test_helper.exs` stops the run with
the list of missing kernels unless `:kernels` is excluded.

### Docs & Utilities

- Generate docs: `mix docs`
- Download SPICE kernels: `mix astro.kernels`

## NIF / C Code Conventions

- Keep C in `c_src/` and build outputs in `priv/`
- Maintain stable NIF function signatures; update Elixir specs when C changes
- Validate inputs in Elixir when possible to keep C code minimal
- When adding new NIFs, add stub definitions in Elixir with `nif_error` fallback

## Configuration & Kernels

- `Astro.Application` reads `config :ex_astro, :spice_kernels, [...]` at
  application startup
- `Astro.Kernel` loads, unloads, and lists kernels at runtime
- Kernel mutations are atomic against the single CSPICE pool and safe at runtime
- `Astro.Kernel.Catalog` is the single list of default NAIF kernels, in SPICE
  load order; edit kernels there only
- Every catalog kernel needs a pinned SHA-256 in the catalog's `@sha256`,
  verified against NAIF's `aa_checksums.txt` MD5 where the directory has one;
  only kernels NAIF replaces in place go in `@unpinned` instead
- The `mix astro.kernels` task downloads the catalog to `priv/kernels/` and
  rejects downloads with a wrong ID word or SHA-256
- The repo's `config/runtime.exs` loads the catalog plus a test fixture in every
  environment; there is no `config/config.exs`. Mix evaluates `runtime.exs`
  after compiling, so it can call project modules
