---
id: TASK-004.06
title: Clean up shared NIF utility hygiene
status: Done
assignee:
  - Codex
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 14:48'
labels:
  - maintenance
  - native
  - planned
dependencies:
  - TASK-004.03
references:
  - c_src/utils.h
  - Makefile
  - test/astro/native_scheduler_test.exs
documentation:
  - c_src/utils.h
  - Makefile
  - AGENTS.md
  - test/astro/native_hygiene_test.exs
modified_files:
  - CHANGELOG.md
  - Makefile
  - c_src/utils.h
  - c_src/time.c
  - c_src/ephemeris.c
  - c_src/support.c
  - test/astro/native_scheduler_test.exs
  - test/astro/native_hygiene_test.exs
parent_task_id: TASK-004
priority: low
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Improve maintainability of the shared native utility layer after string boundary behavior is clarified. The desired outcome is less fragile helper code and stricter compiler feedback for future NIF changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Shared NIF helpers avoid unbounded variable-length stack arrays, or any remaining stack allocation is explicitly bounded, documented, and covered by reviewable checks.
- [x] #2 `utils.h` has normal include protection or shared utility code is split into a clear source/header structure without changing public NIF behavior.
- [x] #3 Native build warnings are tightened for first-party C code enough to catch common NIF prototype, signature, conversion, and allocation-size mistakes without persistent false positives.
- [x] #4 Representative native calls across time, support, and ephemeris modules still compile, load, and preserve their existing successful return shapes.
- [x] #5 Security review and code-adjacent documentation cover helper ownership, allocation bounds, build/process risks, logging, and residual compatibility tradeoffs.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
# Shared NIF Utility Hygiene Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make shared native NIF helpers less fragile and make first-party C build feedback stricter without changing public wrapper behavior.

**Behavior:** Shared helper code has clear ownership and safe inclusion behavior across the three NIF translation units. Native list/binary helper paths avoid unsafe stack allocation patterns and keep existing return shapes. The build warns on common first-party NIF mistakes while avoiding noisy diagnostics from vendored CSPICE code.

**Primary Surfaces:** `c_src/utils.h`; `c_src/ephemeris.c`; `c_src/support.c`; `c_src/time.c`; `Makefile`; native-focused tests under `test/astro/*`; code-adjacent native documentation.

---

### Task 1: Shared Helper Ownership Contract

**Outcome:** The shared NIF utility layer has an explicit inclusion/ownership contract that prevents accidental duplicate declarations or implementation surprises.

**Scope:** Include shared helper declarations/definitions, NIF load/upgrade/unload callbacks, shared constants, and shared native string/list/binary helpers. Exclude changing public Elixir APIs or splitting unrelated feature modules.

**Touches:** `c_src/utils.h`; likely all first-party C files that include it; `Makefile` if the helper structure changes build inputs.

**Dependencies:** `TASK-004.03` complete.

**Behavior:**

- First-party C sources can include shared utilities predictably.
- The helper structure either has normal header protection or an intentional source/header split with clear linkage boundaries.
- Existing per-NIF CSPICE state ownership and load/unload behavior remain intact.

**Acceptance checks:**

- [ ] `c_src/utils.h` can be included safely according to the final chosen structure.
- [ ] Each NIF still owns its intended CSPICE mutex/load/unload state.
- [ ] Native modules still compile and load through existing Elixir NIF modules.

**Notes:** `utils.h` currently contains static helper implementations and NIF lifecycle callbacks, so implementation must preserve per-shared-object state unless deliberately redesigned and documented.

### Task 2: Bounded Native List Construction

**Outcome:** Shared helper code no longer relies on variable-length stack arrays for Erlang term list construction, or any remaining stack allocation is explicitly bounded and justified.

**Scope:** Cover `make_list` and any similar first-party helper patterns found during implementation. Exclude numeric algorithm changes and public return shape changes.

**Touches:** `c_src/utils.h`; NIF call sites returning numeric arrays in `c_src/ephemeris.c`, `c_src/support.c`, and `c_src/time.c` as needed.

**Dependencies:** Task 1.

**Behavior:**

- List construction remains correct for all existing fixed-size SPICE/ERFA outputs.
- Unexpected or future larger lengths cannot silently create unbounded stack pressure.
- Allocation failures, if applicable to the final approach, produce controlled native failures without leaks.

**Acceptance checks:**

- [ ] No first-party shared helper uses an unconstrained variable-length stack array.
- [ ] Existing valid ephemeris, support, and time return values keep their current Elixir shapes.
- [ ] Failure behavior for any newly possible allocation failure is controlled and reviewable.

**Notes:** Current known offender is `ERL_NIF_TERM result[len]` in `make_list`.

### Task 3: First-Party Native Warning Policy

**Outcome:** The native build catches common NIF signature, prototype, conversion, and allocation-size mistakes with warnings that are useful for this project.

**Scope:** Tighten warnings for first-party C sources and headers used by the NIF build. Avoid turning vendored CSPICE extraction/build details into noisy maintenance work.

**Touches:** `Makefile`; possibly first-party C declarations or casts that only exist to satisfy stricter diagnostics.

**Dependencies:** Tasks 1-2 enough to avoid immediately adding warnings around known hygiene issues.

**Behavior:**

- The build reports actionable diagnostics for first-party C mistakes likely to affect NIF safety or ABI correctness.
- Warning settings do not create persistent false positives from vendored or external dependency code.
- Existing build commands remain compatible with `elixir_make`.

**Acceptance checks:**

- [ ] Native compilation succeeds cleanly with the final warning set.
- [ ] The warning set would catch missing prototypes and common type/signature conversion mistakes in first-party NIF code.
- [ ] Build output remains focused on project-owned C code.

**Notes:** Current `CFLAGS` include `-fPIC`, `-finline-functions`, `-Wall`, and `-Wmissing-prototypes`.

### Task 4: Native Hygiene Regression Checks

**Outcome:** Reviewers can verify the utility cleanup and warning policy without relying only on manual inspection.

**Scope:** Add or adjust focused tests/checks around native source hygiene, NIF loading, and representative valid outputs. Exclude exhaustive SPICE numerical validation beyond existing coverage.

**Touches:** Existing native tests under `test/astro/*`; build/check configuration only if needed.

**Dependencies:** Tasks 1-3.

**Behavior:**

- The final helper structure is covered by a durable review or test signal.
- Representative NIF calls still prove valid native load and return behavior.
- Native build warnings are part of the normal verification path or are clearly documented for reviewers.

**Acceptance checks:**

- [ ] A reviewer can verify absence of unsafe VLA helper behavior through tests, source checks, or build diagnostics.
- [ ] Representative valid calls across affected NIF modules still pass.
- [ ] The documented verification command set exercises native compilation.

**Notes:** Prefer checks that fit existing ExUnit and `mix check` patterns.

### Task 5: Security Review

**Outcome:** The final cleanup is reviewed for native-boundary, build, and operational risks touched by this work.

**Scope:** Review input-derived lengths, stack/heap memory behavior, NIF lifecycle callbacks, path/file handling during load, process execution in the build, dependency trust, and native logging. Exclude unrelated SPICE numerical correctness.

**Touches:** Changed C files, `Makefile`, relevant tests, and Backlog notes.

**Dependencies:** Tasks 1-4.

**Behavior:**

- Shared helper changes do not introduce unsafe memory ownership, unbounded stack use, or stale CSPICE global state interactions.
- Warning/build changes do not hide important diagnostics or execute new untrusted commands.
- Operational failures still log enough context to diagnose NIF load/unload/build issues without adding sensitive runtime input exposure.

**Acceptance checks:**

- [ ] Security review confirms bounded allocation behavior and cleanup paths for touched helpers.
- [ ] Security review confirms NIF load/unload state ownership remains correct for each shared object.
- [ ] Security review confirms build and logging changes do not expand file/process/secrets exposure unexpectedly.

**Notes:** Record residual risk or accepted compatibility tradeoffs in task notes.

### Task 6: Document Final Decisions

**Outcome:** Future NIF work has concise guidance for the shared utility structure, allocation policy, and warning policy.

**Scope:** Prefer code-adjacent comments/docs in native files and build comments where they explain non-obvious invariants. Use repo-level docs only if the final decision spans more than native/build ownership.

**Touches:** `c_src/utils.h` or any final shared utility files; `Makefile`; Backlog task notes; optional public docs only if behavior becomes user-visible.

**Dependencies:** Tasks 1-5.

**Behavior:**

- Maintainers can tell why the helper structure is safe to include or how shared declarations/definitions are split.
- Any bounded allocation decision is documented close to the enforcing code.
- Warning choices and any intentionally omitted warning class are recorded where future native edits will see them.

**Acceptance checks:**

- [ ] Code-adjacent documentation explains non-obvious shared helper ownership and allocation constraints.
- [ ] Build comments or task notes explain the final warning policy and any deliberately avoided noisy warning class.
- [ ] Backlog notes summarize final decisions, security review result, and unresolved questions if any.

**Notes:** Unresolved questions: none requiring user input before implementation.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Low. `c_src/utils.h` defines static helper implementations without an include guard and `make_list` uses a variable-length stack array. This task depends on `TASK-004.03` because string helper shape may change there. Classification: AFK.

Planning context gathered 2026-06-13: `TASK-004.03` is Done, so native string boundary behavior and limits are already clarified. `c_src/utils.h` currently includes shared constants, static helper implementations, CSPICE mutex state, and NIF lifecycle callbacks with no include guard. It is included directly by `c_src/time.c`, `c_src/ephemeris.c`, and `c_src/support.c`, which preserves per-NIF shared-object state through `static` linkage. `make_list` currently uses `ERL_NIF_TERM result[len]`, and `Makefile` currently compiles first-party C with `-fPIC -finline-functions -Wall -Wmissing-prototypes`. No repo `docs/` directory exists; documentation should stay code-adjacent unless implementation finds a cross-cutting decision worth a small repo doc.

Planning assumptions: preserve public Elixir APIs, NIF arities, successful return shapes, dirty scheduler choices, and the per-shared-object CSPICE mutex/error-state contract. Warning changes should target project-owned C and avoid noise from vendored CSPICE or external headers. Unresolved questions: none requiring user input before implementation.

Started execution of recorded implementation plan on branch `task-004.04-jd-rounding-carry`. Initial review found no blocking questions; scope remains `c_src/utils.h`, first-party native call sites/tests as needed, `Makefile`, and code-adjacent documentation.

Completed implementation checkpoints for Tasks 1-3: `c_src/utils.h` now has an include guard and explicit per-shared-object ownership comment; `make_list` builds result lists with `enif_make_list_cell` instead of a VLA; `Makefile` applies a stricter first-party warning policy and compiles only `$<` so `utils.h` remains a dependency rather than a compiler input. `mix compile` completed cleanly with the final warning flags.

Verification checkpoint for Tasks 4-5: added `test/astro/native_hygiene_test.exs` to assert the include guard, ownership comment, no VLA list construction pattern, warning flags, and Makefile `$<` compile command. Updated `test/astro/native_scheduler_test.exs` to accept explicit normal-scheduler `0` flags. Focused native tests passed: `mix test test/astro/native_hygiene_test.exs test/astro/time_test.exs test/astro/support_test.exs test/astro/ephemeris_test.exs` -> 29 passed. Full verification passed with `mix check --no-retry` -> compiler, formatter, credo, docs, ExUnit, markdown, and unused_deps success; optional checks skipped because their packages are not installed: dialyzer/dialyxir, doctor, gettext, mix_audit, sobelow.

Security review: helper ownership remains per shared object because `utils.h` still defines static state/functions and `ERL_NIF_INIT` users include it once; include guard prevents duplicate in-translation-unit declarations without changing linkage. `make_list` no longer allocates an input-length array on the stack and introduces no heap allocation or cleanup path. Existing heap allocations in `load_string`, support SPICE cells, and body-value reads retain size checks and cleanup. Build changes do not add new network/process execution; they narrow the compile input from `$^` to `$<`, keep vendored CSPICE linked from the existing archive, and add warnings for first-party C only. Operational logging behavior is unchanged: load/unload and CSPICE synchronization failures still log contextual errors to stderr, including configured kernel paths as before. Residual risk: `-Wno-unused-parameter` intentionally suppresses fixed NIF callback parameter noise so `-Wextra` remains usable; compatibility tradeoff accepted because explicit function table `0` flags and scheduler tests preserve NIF behavior.

Post-finalization commit prep: updated `CHANGELOG.md` Unreleased section with the shared native utility include/allocation/warning hygiene entry before committing the completed task.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented shared native utility hygiene cleanup without changing public NIF behavior.

Summary:
- Added normal include protection and an explicit ownership contract to `c_src/utils.h`, preserving the existing per-shared-object static CSPICE mutex/error/kernel state model.
- Replaced the `make_list` variable-length stack array with reverse `enif_make_list_cell` construction, avoiding unbounded stack allocation while preserving list return shapes.
- Tightened first-party native warnings in `Makefile` with `-Wextra`, prototype/style/signature/conversion/allocation-size/VLA diagnostics, and hard errors for implicit functions, incompatible pointer types, and VLAs; kept vendored CSPICE out of the warning surface by compiling only the C source `$<` and linking the existing archive.
- Made normal-scheduler NIF entries explicit with `0` flags and updated scheduler source tests accordingly.
- Added `test/astro/native_hygiene_test.exs` to cover include guard, ownership documentation, no VLA list pattern, warning policy, and first-party compile command.

Verification:
- `mix format --check-formatted` passed.
- `mix compile` passed cleanly with final native warning flags.
- `mix test test/astro/native_hygiene_test.exs test/astro/time_test.exs test/astro/support_test.exs test/astro/ephemeris_test.exs` passed: 29 tests/doctests.
- `mix test test/astro/native_scheduler_test.exs test/astro/native_hygiene_test.exs` passed: 5 tests.
- `mix check --no-retry` passed: compiler, formatter, credo, docs, ExUnit, markdown, unused_deps. Optional checks were skipped by ex_check because packages are not installed: dialyzer/dialyxir, doctor, gettext, mix_audit, sobelow.
- `git diff --check` passed.

Security review recorded in implementation notes. Residual accepted tradeoff: `-Wno-unused-parameter` suppresses fixed NIF callback parameter noise so `-Wextra` can remain useful without persistent false positives.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Native code compiles cleanly with the final warning policy.
- [x] #2 Relevant ExUnit coverage and `mix check` pass, or any skipped command is documented with the concrete reason.
- [x] #3 No first-party shared helper retains unbounded VLA behavior or ambiguous include ownership.
- [x] #4 Security review is recorded in task notes with residual risks or compatibility tradeoffs.
- [x] #5 Code-adjacent documentation explains final shared utility ownership, allocation bounds, and warning-policy decisions.
- [x] #6 Backlog task is updated at completion with modified files, checked acceptance criteria, and final summary.
<!-- DOD:END -->
