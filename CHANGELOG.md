# Changelog

## Unreleased

- serialize CSPICE-backed NIF access to prevent concurrent kernel/error-state races

## v0.2.2 (2024-10-01)

- updated Elixir dependencies
- added Nix Flake setup

## v0.2.1 (2024-01-07)

- fix loading strings
- new functions
  - `bodvrd`

## v0.2.0 (2024-01-07)

- standardize all functions outputs to be same as in SPICE
- return :ok/:error tuples
- new functions
  - `bodvcd`
  - `oscelt`
  - `conics`
- more documentation

## v0.1.0 (2024-01-03)

- initial release
