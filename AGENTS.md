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
- Single test file: `mix test test/astro_test.exs`
- Single test by line: `mix test test/astro_test.exs:4`
- Tagged tests: `mix test --only <tag>`
- Trace output: `mix test --trace`

### Docs & Utilities

- Generate docs: `mix docs`
- Download SPICE kernels: `mix astro.kernels`

## NIF / C Code Conventions

- Keep C in `c_src/` and build outputs in `priv/`
- Maintain stable NIF function signatures; update Elixir specs when C changes
- Validate inputs in Elixir when possible to keep C code minimal
- When adding new NIFs, add stub definitions in Elixir with `nif_error` fallback

## Configuration & Kernels

- Kernels list is configured at compile time via:
  `config :ex_astro, :spice_kernels, [...]`
- `Astro.NIF` uses `Application.compile_env/3` to read kernels
- The `mix astro.kernels` task writes to `priv/kernels/`

<!-- BACKLOG.MD MCP GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_backlog_instructions()` to load the tool-oriented overview. Use the `instruction` selector when you need `task-creation`, `task-execution`, or `task-finalization`.

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:

- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->
