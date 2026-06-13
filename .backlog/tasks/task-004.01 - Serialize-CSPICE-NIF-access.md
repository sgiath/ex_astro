---
id: TASK-004.01
title: Serialize CSPICE NIF access
status: Done
assignee:
  - Codex
created_date: "2026-06-13 13:35"
updated_date: "2026-06-13 13:47"
labels:
  - security
  - native
dependencies: []
references:
  - c_src/utils.h
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - lib/astro/nif.ex
  - test/astro/time_test.exs
  - test/astro/ephemeris_test.exs
  - Makefile
documentation:
  - >-
    Document the CSPICE synchronization invariant near the native
    helper/lifecycle code that enforces it, most likely in `c_src/utils.h` or a
    nearby native helper if implementation splits it out.
  - >-
    Update `Astro.Time`, `Astro.Ephemeris`, `Astro.Support`, or `README.md` only
    if public behavior, operational setup, or compatibility expectations change.
  - >-
    Record final decisions, rejected alternatives with meaningful
    security/performance impact, and residual risks in Backlog task notes during
    implementation.
modified_files:
  - Makefile
  - c_src/utils.h
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - test/astro/cspice_concurrency_test.exs
parent_task_id: TASK-004
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Prevent races around CSPICE global kernel and error state by ensuring SPICE calls and related error handling execute with native synchronization. The desired outcome is deterministic behavior when multiple BEAM scheduler threads call SPICE-backed NIFs concurrently.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Concurrent calls to SPICE-backed NIFs cannot interleave CSPICE calls with `failed_c`, `getmsg_c`, or `reset_c` error handling.
- [x] #2 The NIF load/unload lifecycle initializes and releases any synchronization primitive safely, including partial load failure paths.
- [x] #3 A regression test or stress check exercises concurrent SPICE-backed calls without inconsistent errors or crashes.
- [x] #4 ERFA-only time conversion behavior remains unchanged by CSPICE synchronization work.
- [x] #5 Operational failures around kernel loading or synchronization lifecycle log enough context to diagnose the failing module/path without adding sensitive-data exposure beyond configured kernel paths.
- [x] #6 Security review and code-adjacent documentation for the native synchronization invariant are completed.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Serialize CSPICE NIF Access Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SPICE-backed NIF calls execute deterministically under concurrent BEAM scheduler access by protecting CSPICE global state and error handling with native synchronization.

**Behavior:** Concurrent calls into `Astro.Ephemeris`, `Astro.Support`, and SPICE-backed `Astro.Time` functions no longer interleave CSPICE operations with `failed_c`, `getmsg_c`, or `reset_c`. Kernel loading and CSPICE error-mode setup remain reliable during NIF load, and synchronization lifecycle failures are surfaced clearly. Public Elixir APIs and return shapes remain compatible unless implementation uncovers an existing bug that must be fixed to satisfy the task.

**Primary Surfaces:** `c_src/utils.h`, `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`, `lib/astro/nif.ex`, `test/astro/time_test.exs`, `test/astro/ephemeris_test.exs`, native build/link behavior in `Makefile`.

---

### Task 1: CSPICE Synchronization Boundary

**Outcome:** Every CSPICE-backed NIF has a clear native synchronization boundary that protects the CSPICE call and its associated error-state read/reset sequence as one non-interleavable operation.

**Scope:** Includes all CSPICE calls in ephemeris, support, SPICE-backed time helpers, kernel loading, and CSPICE error-mode setup. Excludes ERFA-only calls that do not touch CSPICE state.

**Touches:** `c_src/utils.h`, `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`, `Makefile` if synchronization linkage/build flags require it.

**Dependencies:** None.

**Behavior:**

- Concurrent BEAM scheduler threads cannot enter overlapping CSPICE/global-error sections that share the same CSPICE state.
- Error checks and message extraction observe the error state from the CSPICE call that just completed, then reset that same state before another protected CSPICE call can run.
- Input decoding and Elixir term construction remain outside the protected section where they do not depend on CSPICE global state.

**Acceptance checks:**

- [ ] Review of all non-vendored `*_c` SPICE calls confirms each shared-state call is covered by synchronization appropriate to the actual CSPICE linkage/global-state topology.
- [ ] Review confirms `failed_c`, `getmsg_c`, and `reset_c` cannot be interleaved with another protected CSPICE call.
- [ ] ERFA-only functions in `c_src/time.c` preserve existing behavior and are not coupled to CSPICE locking except through shared helper constraints that are justified by implementation.

**Notes:** Implementation must verify whether statically linked CSPICE objects are isolated per NIF shared object or share process-wide state, then ensure the synchronization boundary matches that reality.

### Task 2: NIF Load/Unload Lifecycle Safety

**Outcome:** Synchronization resources are initialized before any CSPICE work, released safely when each NIF library unloads, and handled deterministically on load failure paths.

**Scope:** Includes NIF `load`, `upgrade`, and `unload` lifecycle behavior plus load-time kernel furnishing. Excludes runtime kernel-management APIs, which do not exist in the current public surface.

**Touches:** `c_src/utils.h`, all `ERL_NIF_INIT` users, `lib/astro/nif.ex` for load-time context/log expectations if needed.

**Dependencies:** Task 1.

**Behavior:**

- CSPICE error mode setup and kernel furnishing occur only after synchronization is usable.
- Load failures release any native resources already acquired and keep current failure semantics visible to `:erlang.load_nif/2`.
- Unload is safe after successful load and after partial load failure cleanup.

**Acceptance checks:**

- [ ] NIF load succeeds with the configured kernels that currently load in tests.
- [ ] Missing or invalid kernel load failures still report kernel path context and do not leave synchronization resources in an invalid state.
- [ ] Unload/upgrade callbacks have explicit behavior that is compatible with the synchronization resource lifecycle.

**Notes:** Existing `Astro.NIF` already logs configured-but-missing kernel paths before `load_nif`; native load currently logs CSPICE kernel load failures to stderr.

### Task 3: Concurrent Regression Coverage

**Outcome:** The test suite includes a focused concurrent stress/regression check that would expose mismatched CSPICE results, corrupted CSPICE error state, crashes, or inconsistent error tuples under scheduler concurrency.

**Scope:** Covers representative successful and failing SPICE-backed calls from the affected modules. Excludes benchmarking and exhaustive thread-safety proof across every CSPICE primitive.

**Touches:** `test/astro/time_test.exs`, `test/astro/ephemeris_test.exs`, possibly a new focused native-concurrency test file, test helper/config if needed.

**Dependencies:** Tasks 1 and 2.

**Behavior:**

- Concurrent successful calls return stable values equivalent to sequential calls.
- Concurrent failing calls return errors attributable to their own invalid input rather than leaked error state from another call.
- The stress check is deterministic enough for normal `mix test` use and does not require downloading external kernels during the test run.

**Acceptance checks:**

- [ ] A reviewer can identify the test or stress check that exercises concurrent SPICE-backed NIF calls.
- [ ] The check covers at least one CSPICE success path and one CSPICE error path.
- [ ] `mix test` passes repeatedly without intermittent crashes or inconsistent CSPICE errors in the added concurrency coverage.

**Notes:** Existing ExUnit tests are async, but they do not intentionally coordinate simultaneous calls around CSPICE error handling.

### Task 4: Security Review

**Outcome:** The native synchronization change is reviewed for security and operational risks introduced or affected by locking, CSPICE error handling, file paths, logging, and process lifecycle behavior.

**Scope:** Covers native synchronization primitives, CSPICE global state/error handling, kernel file path handling, native memory allocation/freeing, load/unload failure paths, logging, and build/link changes. Excludes unrelated public API design review.

**Touches:** Native files touched by implementation, `Makefile` if changed, tests that exercise failure behavior, task notes for recorded findings.

**Dependencies:** Tasks 1 through 3.

**Behavior:**

- Invalid inputs continue to fail without unsafe memory access, deadlock, or stale CSPICE error leakage.
- Logs include enough context to diagnose synchronization or kernel load failures while avoiding new exposure of secrets beyond existing configured kernel paths.
- Build or dependency changes do not introduce unnecessary external trust or privilege surfaces.

**Acceptance checks:**

- [ ] Review confirms no lock path can leave the synchronization primitive permanently held after input errors, CSPICE errors, or early cleanup.
- [ ] Review confirms native allocation/freeing still covers all decoded strings and partial-failure paths.
- [ ] Review confirms operational logs include context for kernel load and synchronization lifecycle failures without logging arbitrary binary payloads.
- [ ] Review notes any residual risk or confirms none found.

**Notes:** This task is required because the change touches native code, global library state, and process-wide scheduling behavior.

### Task 5: Documentation of Decisions

**Outcome:** The final implementation records the synchronization invariant, lifecycle ownership, and relevant compatibility/security decisions close to the code that future maintainers will inspect.

**Scope:** Includes code-adjacent documentation for native synchronization behavior and public docs only if user-visible semantics change. Excludes broad architectural docs unless implementation decisions span multiple workflows beyond the NIF boundary.

**Touches:** `c_src/utils.h` or nearby native helper docs/comments, module docs in `lib/astro/*` if behavior changes, `README.md` only if operational/kernel-loading guidance changes.

**Dependencies:** Tasks 1 through 4.

**Behavior:**

- Maintainers can see which CSPICE operations must remain inside the synchronization boundary and why.
- Lifecycle ownership of synchronization resources is documented where load/unload behavior is maintained.
- Any rejected alternatives with meaningful security, compatibility, or performance implications are recorded in task notes or code-adjacent docs.

**Acceptance checks:**

- [ ] Native synchronization invariant is documented near the helper or lifecycle code that enforces it.
- [ ] Public documentation is updated if public behavior, operational setup, or compatibility expectations change.
- [ ] Task notes capture final decisions and any residual risks discovered during implementation.

**Notes:** Prefer concise native comments/module docs over a new `docs/` file unless the final design has repo-wide operational implications.

Execution note: implemented the recorded plan with per-NIF ErlNifMutex synchronization plus `-Wl,-Bsymbolic` so each shared object binds internally to its own statically linked CSPICE copy. This avoided adding a process-global OS semaphore and keeps lifecycle ownership inside the NIF load/unload callbacks.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Planning context gathered on 2026-06-13.

Existing structure:

- `c_src/utils.h` is included by each non-vendored NIF C file and currently owns shared helpers, `handle_error/1`, and NIF `load`/`upgrade`/`unload` callbacks.
- `c_src/ephemeris.c` calls CSPICE ephemeris/orbit routines and checks `failed_c` after each call.
- `c_src/support.c` calls CSPICE body/kernel support routines and checks `failed_c` after each call.
- `c_src/time.c` mixes ERFA-only date/time conversions with SPICE-backed helpers: `str2et_c`, `utc2et_c`, `unitim_c`, `j2000_c`, and `spd_c`.
- `Astro.NIF` logs configured-but-missing kernel paths before `:erlang.load_nif/2`; native `load` configures CSPICE error behavior and furnishes configured kernels.
- Existing tests are async and cover SPICE-backed happy paths and error paths, but there is no intentional concurrency stress around CSPICE global error state.

Planning assumptions:

- Public Elixir API shape should remain stable.
- The implementation should protect the CSPICE call plus `failed_c`/`getmsg_c`/`reset_c` as one native critical section.
- Implementation must verify whether the current static CSPICE linkage creates separate global state per NIF shared object or shared process-wide state, and choose synchronization scope accordingly.
- No user-facing unresolved questions for planning.

2026-06-13: Execution started. Existing implementation plan is already recorded in the task and user requested implementation, so proceeding against that plan.

2026-06-13: CSPICE synchronization implemented in `c_src/utils.h` with a lifecycle-owned ErlNifMutex. Kernel loading, CSPICE error-mode setup, runtime SPICE calls, error extraction/reset, `j2000_c`/`spd_c`, and unload `kclear_c` now execute under the native lock where applicable.

2026-06-13: Linkage review found CSPICE symbols exported from each NIF shared object. Added `-Wl,-Bsymbolic`; `readelf -d` confirmed `SYMBOLIC` on `priv/time.so`, `priv/ephemeris.so`, and `priv/support.so`, making per-NIF CSPICE state/mutex ownership match the actual binding model.

2026-06-13: Added `test/astro/cspice_concurrency_test.exs`, which runs concurrent SPICE success paths (`Astro.Time.utc2et/1`, `Astro.Ephemeris.conics/2`) and a SPICE error path (`Astro.Time.str2et/1`) to exercise scheduler concurrency without new kernel downloads.

2026-06-13 security review: no lock path intentionally returns while holding the mutex; all CSPICE error paths read/reset error state before unlock. Decoded native strings are still freed on cleanup paths. Logs cover mutex init failure, synchronization unavailable, error-mode setup failure, kernel path load failure, kernel-path decode failure, and unload cleanup failure. No arbitrary binary payloads are logged beyond existing configured kernel paths.

2026-06-13 rejected alternatives/residual risk: rejected a named OS semaphore because it would add cross-process namespace/DoS concerns and weaker ownership semantics. Residual risk is that `-Wl,-Bsymbolic` is ELF/linker-specific; current project target is Linux GCC CSPICE as reflected by the existing Makefile URL.

<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->

author: Codex
created: 2026-06-13 13:40

---

## Implementation plan written and saved. Task remains ready for an implementing agent; no code changes were made during planning.

author: Codex
created: 2026-06-13 13:40

---

## Planning label cleared after saving the implementation plan; status left as `To Do` for execution.

<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Implemented native serialization for CSPICE-backed NIFs. `c_src/utils.h` now owns the CSPICE synchronization invariant, mutex lifecycle, locked error extraction/reset, load failure cleanup, and unload kernel cleanup. `c_src/ephemeris.c`, `c_src/support.c`, and the SPICE-backed portions of `c_src/time.c` now hold the mutex around CSPICE calls and their associated `failed_c`/`getmsg_c`/`reset_c` sequence while leaving ERFA-only conversions unchanged.

Added `-Wl,-Bsymbolic` in the Makefile so each NIF shared object binds to its own statically linked CSPICE copy and per-NIF mutex. Added a concurrent SPICE regression test covering successful and failing calls.

Verification: `mix compile`, `mix test`, and `mix check` all pass. `readelf -d` confirmed the generated NIF shared objects have the `SYMBOLIC` flag.

<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [x] #1 `mix compile` succeeds after native synchronization changes.
- [x] #2 Relevant tests, including the added concurrent SPICE regression/stress coverage, pass locally with `mix test`.
- [x] #3 All non-vendored CSPICE calls that share global state are covered by the chosen native synchronization boundary and keep CSPICE error handling non-interleavable.
- [x] #4 Synchronization lifecycle failures and kernel load operational issues log actionable context without introducing new sensitive-data exposure.
- [x] #5 Security review is completed and recorded before finalizing the task.
- [x] #6 Code-adjacent documentation captures the synchronization invariant and lifecycle ownership.
<!-- DOD:END -->
