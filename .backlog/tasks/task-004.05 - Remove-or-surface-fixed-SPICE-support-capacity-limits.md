---
id: TASK-004.05
title: Remove or surface fixed SPICE support capacity limits
status: Done
assignee:
  - Codex
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 14:42'
labels:
  - bug
  - native
  - planned
dependencies: []
references:
  - c_src/support.c
  - lib/astro/support.ex
  - test/astro/support_test.exs
  - test/astro/native_string_boundary_test.exs
  - test/astro/native_scheduler_test.exs
documentation:
  - lib/astro/support.ex
  - README.md
modified_files:
  - CHANGELOG.md
  - c_src/support.c
  - c_src/utils.h
  - config/config.exs
  - lib/astro/support.ex
  - test/astro/support_test.exs
  - test/fixtures/kernels/ex_astro_test_many_values.tpc
parent_task_id: TASK-004
priority: low
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address hidden native capacity limits in SPICE support helpers. The desired outcome is either dynamic handling of valid larger results or explicit public errors/documentation when `spkobj`, `bodvcd`, or `bodvrd` exceed supported capacity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `spkobj/1` no longer silently depends on an undocumented 1000-ID native result cap; larger valid results are returned or fail with an explicit documented capacity error.
- [x] #2 `bodvcd/2` and `bodvrd/2` no longer silently depend on an undocumented 16-value native result cap; larger valid results are returned or fail with an explicit documented capacity error.
- [x] #3 Normal support calls for representative bundled kernels continue to return the existing `{:ok, list}` shapes and values.
- [x] #4 Capacity-exceeded behavior, if any cap remains, is covered by tests or documented examples for `spkobj/1`, `bodvcd/2`, and `bodvrd/2`.
- [x] #5 Native string validation, CSPICE mutex/error reset behavior, and scheduler classifications remain compatible with existing tests.
- [x] #6 Public documentation reflects the final capacity behavior and any retained limits.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
# SPICE Support Capacity Limits Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SPICE support helpers handle or explicitly reject result sets larger than their current hidden native buffers.

**Behavior:** `Astro.Support.spkobj/1`, `bodvcd/2`, and `bodvrd/2` no longer rely on undocumented native result capacities. Valid larger SPICE results are returned when practical; if a capacity limit remains, callers receive a clear `{:error, reason}` and public docs state the supported bound. Existing normal results and native string validation behavior remain unchanged.

**Primary Surfaces:** `c_src/support.c`, `c_src/utils.h`, `lib/astro/support.ex`, support/native boundary tests, scheduler/error-contract tests, generated ExDoc docs.

---

### Task 1: Public Capacity Contract

**Outcome:** Each affected support API has a clear result-capacity contract.

**Scope:** Decide for `spkobj/1`, `bodvcd/2`, and `bodvrd/2` whether larger results are dynamically supported or explicitly capped. Excludes unrelated SPICE wrappers and existing native string limits.

**Touches:** `lib/astro/support.ex`, `c_src/support.c`, existing task notes and SPICE API references.

**Dependencies:** None.

**Behavior:**

- Callers can infer from behavior and docs whether larger result sets are supported.
- Any retained cap has a stable public failure shape instead of hidden truncation, memory risk, or opaque CSPICE failure.
- The Elixir specs remain compatible with the existing `{:ok, list} | {:error, reason}` surface.

**Acceptance checks:**

- [ ] The implementation makes a reviewable choice for each affected API: dynamic result handling or explicit capacity error.
- [ ] No public function changes return tuple shape or raises for valid binary inputs solely because results exceed the old hidden capacity.
- [ ] Existing behavior for normal `RADII` and `de440.bsp` support calls remains compatible.

**Notes:** Prefer dynamic handling when it is simple and reliable; retain a cap only when the SPICE API makes dynamic sizing impractical for this library slice.

### Task 2: `spkobj/1` Capacity Behavior

**Outcome:** SPK object discovery does not silently depend on a 1000-ID native cell.

**Scope:** Covers only result capacity and error reporting for `spkobj/1`. Excludes path validation, scheduler classification, and kernel download behavior unless directly affected.

**Touches:** `c_src/support.c`, `lib/astro/support.ex`, `test/astro/support_test.exs` or a focused support-capacity test.

**Dependencies:** Task 1.

**Behavior:**

- SPK files with object counts within the supported contract return all IDs as an Elixir list.
- SPK files above any retained support limit return a clear `{:error, reason}` that identifies capacity, not a misleading file or generic CSPICE failure.
- CSPICE error state is still read and reset while holding the existing mutex contract.

**Acceptance checks:**

- [ ] Normal `spkobj/1` tests still prove the public `{:ok, ids}` shape and representative body IDs.
- [ ] A capacity-focused test or documented fixture strategy covers behavior beyond the previous 1000-ID assumption or the explicit retained cap.
- [ ] Scheduler tests still classify `spkobj/1` as dirty IO.

**Notes:** Avoid adding large binary fixtures unless they provide durable value; a native-level seam, generated fixture, or documented example is acceptable if reviewable.

### Task 3: `bodvcd/2` and `bodvrd/2` Capacity Behavior

**Outcome:** Kernel-pool body value reads do not silently depend on a 16-value native array.

**Scope:** Covers numeric value result capacity for ID-based and name-based body constants. Excludes body-name translation and unrelated kernel-pool APIs.

**Touches:** `c_src/support.c`, `lib/astro/support.ex`, support tests, native string boundary tests if validation messages or limits are touched.

**Dependencies:** Task 1.

**Behavior:**

- Normal body constants such as Earth `RADII` continue returning all expected doubles.
- Kernel variables with more than 16 numeric values are either returned completely or fail with a clear capacity error.
- `bodvcd/2` and `bodvrd/2` remain consistent with each other for equivalent body/item inputs.

**Acceptance checks:**

- [ ] Tests cover normal `bodvcd/2` and `bodvrd/2` values from loaded kernels.
- [ ] Tests or documented examples cover value-count behavior above 16 for both ID and name variants, including the error text if a cap remains.
- [ ] Existing invalid native string behavior continues to raise `ArgumentError` before CSPICE observes the input.

**Notes:** A tiny text-kernel fixture is preferable to relying on a large external kernel when demonstrating many-value kernel-pool behavior.

### Task 4: Native Error and Regression Coverage

**Outcome:** Capacity changes preserve existing NIF error, allocation, and scheduler contracts.

**Scope:** Review regression behavior around CSPICE failures, allocation failures where observable, and mutex/error reset paths. Excludes broad NIF utility cleanup covered by `TASK-004.06`.

**Touches:** `c_src/support.c`, `c_src/utils.h`, `test/astro/support_test.exs`, `test/astro/native_scheduler_test.exs`.

**Dependencies:** Tasks 2 and 3.

**Behavior:**

- Operational failures return the established `{:error, reason}` tuple and include enough context to diagnose capacity or CSPICE failure source.
- Native allocations and cleanup paths do not leak, double-free, or leave the CSPICE mutex locked on errors.
- Existing scheduler classifications remain intentional after any capacity-related work.

**Acceptance checks:**

- [ ] Support-related tests cover successful calls, invalid input boundaries, and capacity-exceeded behavior when applicable.
- [ ] `mix test` passes for support, native string boundary, and native scheduler coverage.
- [ ] Any new native operational error message distinguishes capacity from missing kernel data or invalid files.

**Notes:** Logging is expected for unexpected native operational issues where stderr logging is already used; ordinary public capacity errors can remain return values if documented.

### Task 5: Security Review

**Outcome:** The capacity fix does not introduce unsafe native memory, file, input, or logging behavior.

**Scope:** Review only surfaces touched by this task: support NIF inputs, result allocation, CSPICE error handling, file path use in `spkobj/1`, loaded kernel data, and public docs. Authentication and authorization are not applicable in this library.

**Touches:** `c_src/support.c`, `c_src/utils.h`, `lib/astro/support.ex`, tests/docs changed for this task.

**Dependencies:** Tasks 2-4.

**Behavior:**

- Native allocations are bounded by a documented contract or data-derived limit with failure behavior.
- Caller-controlled strings retain existing length and embedded-NUL protections.
- Errors and logs do not expose more than caller-supplied paths/items and CSPICE diagnostics already visible through the public API.

**Acceptance checks:**

- [ ] Review confirms no unbounded allocation, buffer overflow, path traversal expansion, unsafe deserialization, or privilege change was introduced.
- [ ] Review confirms CSPICE mutex/error reset behavior is preserved on success and failure paths.
- [ ] Review confirms capacity diagnostics are useful without logging secrets, credentials, or unrelated process state.

**Notes:** This task should explicitly record any retained cap and its rationale.

### Task 6: Documentation of Decisions

**Outcome:** Final capacity behavior and implementation decisions are documented close to the support API.

**Scope:** Update public docs and code-adjacent notes for the affected support helpers. Excludes broad SPICE tutorial documentation unless the implementation creates new operational workflow.

**Touches:** `lib/astro/support.ex`, optional `README.md`, task final notes.

**Dependencies:** Tasks 1-5.

**Behavior:**

- Public docs describe any retained capacity limits and capacity-exceeded error behavior.
- If dynamic handling removes the old limits, docs avoid mentioning obsolete caps and examples still reflect normal usage.
- Planning and implementation decisions are captured so future agents do not reintroduce hidden fixed buffers.

**Acceptance checks:**

- [ ] ExDoc-visible docs for `spkobj/1`, `bodvcd/2`, and `bodvrd/2` match implemented capacity behavior.
- [ ] Any retained cap has a documented rationale and caller-visible error contract.
- [ ] Task notes/final summary record the chosen approach, rejected alternative if meaningful, and verification performed.

**Notes:** Prefer module/function docs over a new `docs/` file because this repo has no docs directory and the behavior is API-local.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Low. `c_src/support.c` uses `SPICEINT_CELL(ids, 1000)` for `spkobj` and `SpiceDouble values[16]` for `bodvcd`/`bodvrd`; valid larger kernel data may fail in undocumented ways. Classification: AFK.

Planning context gathered 2026-06-13: `c_src/support.c` currently declares `SPICEINT_CELL(ids, 1000)` plus `ERL_NIF_TERM erl_ids[1000]` in `spkobj/1`, and `SpiceDouble values[16]` with maxn `16` in both `bodvcd/2` and `bodvrd/2`. `lib/astro/support.ex` documents native string limits but no result-capacity limits. Existing tests cover normal `spkobj/1`, native string boundaries, and scheduler flags; normal `bodvcd/2`/`bodvrd/2` and result-capacity behavior need coverage. No repo `docs/` directory exists; code-adjacent ExDoc docs are the right primary documentation surface. Unresolved questions: none.

Execution started on 2026-06-13. Reviewed existing implementation plan; no blocking concerns before implementation. Proceeding task-by-task with tests first where practical.

Chosen approach: `spkobj/1` now uses dynamically allocated `SpiceCell` storage, starting at 1024 IDs and retrying on CSPICE `SPICE(SETEXCESS)` up to a documented 65,536-ID ceiling with an explicit capacity error. `bodvcd/2` and `bodvrd/2` now build the `BODY<id>_<item>` kernel variable name, use `dtpool_c` to discover numeric dimension/type, and fetch all values with `gdpool_c`, removing the old 16-value buffer. Added a tiny text-kernel fixture for >16-value coverage and updated ExDoc-visible support docs.

Security review 2026-06-13: native allocations are bounded by either the documented `spkobj/1` ceiling (65,536 IDs) or the kernel-pool dimension returned by `dtpool_c`, with overflow checks before allocation. Caller strings still go through existing `load_string` limits and embedded-NUL rejection. CSPICE calls remain under the existing mutex/error-reset contract, including retry/error paths. Cleanup frees allocated SPK cells, body value buffers, and decoded strings on success and failure. File-path behavior is unchanged except for the tracked test fixture path in config. Capacity diagnostics expose only caller-supplied paths/items, constructed kernel variable names, and CSPICE-style errors already returned by the API; no secrets or unrelated process state are logged.

Verification 2026-06-13: `mix test test/astro/support_test.exs test/astro/native_string_boundary_test.exs test/astro/native_scheduler_test.exs` passed (9 tests). `mix test` passed (33 passed, including 10 doctests). `mix check` passed compiler, unused_deps, formatter, credo, ex_doc, ex_unit, and markdown; optional checks were skipped because their packages are not installed. `git diff --check` passed.

Changelog updated before commit: `CHANGELOG.md` now records the removal of hidden SPICE support result caps for `spkobj`, `bodvcd`, and `bodvrd` under Unreleased.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->

author: Codex
created: 2026-06-13 14:15

---

## Planning completed with `write-plan`: structured plan, acceptance criteria, documentation expectations, and Definition of Done added. Label changed from `needs-planning` to `planned`.

<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented explicit/dynamic capacity handling for SPICE support helpers.

- `spkobj/1` now allocates SPICE integer cells dynamically, retries on CSPICE set-capacity errors, and documents/returns a clear error if a file exceeds the retained 65,536-ID ceiling.
- `bodvcd/2` and `bodvrd/2` now size numeric results from the kernel pool with `dtpool_c` and fetch the complete value list with `gdpool_c`, removing the previous 16-value native buffer. `bodvrd/2` keeps numeric body-string compatibility through `bods2c_c`.
- Added a tracked text-kernel fixture and support tests covering normal `RADII`, >16-value constants, `spkobj` fixed-buffer regression, native string boundaries, and scheduler classification.
- Updated ExDoc-visible `Astro.Support` docs with the final capacity contract.

Verification: focused support/native tests passed; full `mix test` passed; full `mix check` passed. Security review found no unbounded allocation, buffer overflow, path traversal expansion, unsafe deserialization, privilege change, CSPICE mutex leak, or sensitive logging expansion introduced by this change.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Relevant support/native tests pass, including normal results and capacity behavior.
- [x] #2 `mix test` passes or any unrelated failure is documented with command output.
- [x] #3 Security review completed for native allocation, input validation, CSPICE error handling, file path use, and logging/error messages.
- [x] #4 ExDoc-visible support API docs match the implemented capacity contract.
- [x] #5 Backlog task records final chosen approach, modified files, and verification performed.
<!-- DOD:END -->
