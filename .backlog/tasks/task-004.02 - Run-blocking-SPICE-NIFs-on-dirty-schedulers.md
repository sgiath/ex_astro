---
id: TASK-004.02
title: Run blocking SPICE NIFs on dirty schedulers
status: Done
assignee:
  - Codex
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 13:59'
labels:
  - performance
  - native
dependencies: []
references:
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - lib/astro/ephemeris.ex
  - lib/astro/support.ex
  - lib/astro/time.ex
documentation:
  - >-
    Code-adjacent comments near `ErlNifFunc` registration tables in
    `c_src/ephemeris.c`, `c_src/support.c`, and `c_src/time.c` documenting
    normal vs dirty CPU vs dirty IO classification.
  - >-
    Optional repo-level documentation only if final scheduler policy spans
    multiple files in a way that code-adjacent comments cannot keep clear.
modified_files:
  - CHANGELOG.md
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - test/astro/ephemeris_test.exs
  - test/astro/native_scheduler_test.exs
  - test/astro/support_test.exs
parent_task_id: TASK-004
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Protect BEAM scheduler responsiveness by marking file-backed or potentially heavy SPICE NIF calls as dirty jobs where appropriate. The desired outcome is that kernel inspection and ephemeris work no longer run on normal schedulers when they can block.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 SPICE NIF calls with direct file I/O, file-backed ephemeris access, or potentially long computation are registered with the appropriate dirty scheduler flags.
- [x] #2 Short ERFA-only time conversions remain on normal schedulers unless implementation evidence justifies dirty scheduling.
- [x] #3 CSPICE mutex/error isolation remains intact when dirty-scheduled calls run concurrently.
- [x] #4 NIFs rebuild/load successfully and representative public calls keep their existing arities, specs, return shapes, and error behavior.
- [x] #5 Scheduler classification decisions and any residual NIF load/unload limitation are documented close to the NIF registration code.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
# Dirty SPICE NIF Scheduler Classification Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SPICE-backed NIF calls that can block or run long no longer execute on normal BEAM schedulers.

**Behavior:** File-backed SPICE inspection and ephemeris work are registered as dirty jobs with a documented CPU/IO classification. Short ERFA-only time conversions remain normal scheduler NIFs unless implementation evidence shows otherwise. Public Elixir APIs, return shapes, and CSPICE error isolation remain unchanged.

**Primary Surfaces:** `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`, `c_src/utils.h`, `lib/astro/ephemeris.ex`, `lib/astro/support.ex`, `lib/astro/time.ex`, `test/astro/*`

---

### Task 1: Scheduler Classification Contract

**Outcome:** Every exported NIF has an explicit scheduler classification and rationale.

**Scope:** Classify existing `ephemeris`, `support`, and `time` NIFs only. Include dirty CPU vs dirty IO decision for SPICE-backed calls and normal scheduler decision for ERFA-only calls.

**Touches:** `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`, nearby tests/docs.

**Dependencies:** None.

**Behavior:**

- Classifications cover ephemeris retrieval, SPK file inspection, body/kernel-pool lookup, SPICE time conversion, simple SPICE constants, and ERFA-only conversions.
- File path inspection and any call likely to block on kernel/file access are treated differently from pure numeric ERFA work.
- The CSPICE mutex contract remains part of the classification, since dirty jobs can still run concurrently on dirty scheduler threads.

**Acceptance checks:**

- [ ] A reviewer can map every `ErlNifFunc` entry to dirty IO, dirty CPU, or normal scheduler with no unclassified entries.
- [ ] Classification explains why ERFA-only conversions stay normal and why selected SPICE calls move dirty.

**Notes:** Current registrations use only name/arity/function entries. `spkobj_c` reads the path passed to `spkobj/1`; `spkezr_c`, `spkez_c`, and `spkgeo_c` perform ephemeris work against loaded SPICE data; `str2et_c`, `utc2et_c`, `unitim_c`, `j2000_c`, and `spd_c` are CSPICE-backed time calls; most other time conversions are ERFA-only.

### Task 2: Dirty Scheduling for Ephemeris and Kernel Inspection

**Outcome:** Ephemeris state retrieval and direct SPK inspection no longer run on normal schedulers.

**Scope:** Apply the classification to `Astro.Ephemeris` NIF registrations and `Astro.Support.spkobj/1`. Preserve current locking, error handling, arities, and return shapes.

**Touches:** `c_src/ephemeris.c`, `c_src/support.c`, `test/astro/ephemeris_test.exs`, `test/astro/cspice_concurrency_test.exs`.

**Dependencies:** Task 1.

**Behavior:**

- `spkezr/5`, `spkez/5`, and `spkgeo/4` run as dirty jobs because they may be computationally heavy and depend on SPICE ephemeris data.
- `spkobj/1` runs as a dirty job appropriate for direct SPK file inspection.
- CSPICE error state remains isolated under the existing mutex, including dirty scheduler execution.

**Acceptance checks:**

- [ ] NIF registration entries for classified ephemeris and SPK inspection calls include the expected dirty scheduler flags.
- [ ] Existing successful and error return shapes for these calls are unchanged.

**Notes:** Do not broaden this task into CSPICE serialization changes; that belongs to `TASK-004.01` and current mutex behavior should be preserved.

### Task 3: Time and Support NIF Classification Applied Conservatively

**Outcome:** Time/support NIFs use dirty scheduling only where their SPICE behavior justifies it.

**Scope:** Apply Task 1 classification to `c_src/time.c` and remaining `c_src/support.c` registrations. Keep short ERFA-only conversions on normal schedulers.

**Touches:** `c_src/time.c`, `c_src/support.c`, `lib/astro/time.ex`, `lib/astro/time/nif.ex`, `test/astro/time_test.exs`, support tests if added.

**Dependencies:** Task 1.

**Behavior:**

- ERFA-only conversions such as Julian date and TAI/TT/UTC transformations remain normal scheduler NIFs.
- SPICE-backed parsing/conversion and kernel-pool lookup calls are dirty only when the classification shows blocking or long-running risk.
- Bad argument behavior, SPICE error tuple behavior, and public API specs remain compatible.

**Acceptance checks:**

- [ ] A reviewer can see ERFA-only NIFs remain unflagged or otherwise normal scheduler.
- [ ] SPICE-backed time/support calls selected by classification have matching dirty flags and unchanged public behavior.

**Notes:** `load/3` and `unload/1` callbacks call CSPICE and can perform kernel I/O, but they are not `ErlNifFunc` entries. Treat any residual load/unload scheduler risk as a documented limitation unless this task is intentionally expanded.

### Task 4: Runtime and API Verification

**Outcome:** Dirty scheduler registration is proven not to break loading, calls, or existing concurrency guarantees.

**Scope:** Verify the NIF shared objects build/load, public Elixir calls still work, and existing CSPICE concurrency/error isolation tests remain meaningful.

**Touches:** `test/astro/*`, `mix.exs` only if verification support already exists there.

**Dependencies:** Tasks 2 and 3.

**Behavior:**

- Tests exercise representative dirty-scheduled SPICE calls and normal ERFA-only calls.
- Verification includes at least one successful SPICE call and one SPICE error path after dirty registration.
- Public module names, arities, specs, and return values remain stable.

**Acceptance checks:**

- [ ] `mix test` passes with the NIFs rebuilt.
- [ ] Verification covers NIF load, one dirty-scheduled SPICE success, one dirty-scheduled SPICE error, and one normal ERFA-only conversion.

**Notes:** Use existing tests where sufficient; add focused coverage only for behavior not already protected.

### Task 5: Security Review

**Outcome:** Scheduler changes do not introduce new native-code, file, logging, or dependency risk.

**Scope:** Review only surfaces touched by this task: NIF registration metadata, CSPICE locking/error handling interaction, file-path handling for `spkobj/1`, kernel loading side effects, and test fixtures.

**Touches:** `c_src/*.c`, `c_src/utils.h`, tests/docs touched by implementation.

**Dependencies:** Tasks 2-4.

**Behavior:**

- Dirty execution does not weaken CSPICE global-state serialization or error cleanup.
- No secrets or excessive file paths are newly logged; existing operational errors retain enough context to debug failures.
- No new external dependencies, shell execution, or broader file access are introduced.

**Acceptance checks:**

- [ ] Review confirms dirty scheduler threads still hold the CSPICE mutex around CSPICE calls and error reset paths.
- [ ] Review confirms `spkobj/1` path behavior is unchanged and no new sensitive logging or dependency risk was added.

**Notes:** If implementation reveals a pre-existing path validation issue, record it as follow-up unless it is directly caused by this scheduler change.

### Task 6: Document Scheduler Decisions

**Outcome:** Future NIF additions have local guidance for choosing normal, dirty CPU, or dirty IO registration.

**Scope:** Document final classifications and relevant tradeoffs close to the NIF registration code first; use repo-level docs only if the explanation spans modules.

**Touches:** Prefer comments/module docs near `c_src/*` registration tables; optional README or docs only if needed.

**Dependencies:** Tasks 1-5.

**Behavior:**

- Documentation captures final classification decisions, especially why ERFA-only calls stay normal.
- Documentation calls out residual NIF load/unload callback behavior if it remains outside dirty scheduler registration.
- Documentation is concise enough to maintain with new NIFs.

**Acceptance checks:**

- [ ] Code-adjacent docs explain dirty scheduler classification for current NIF registrations.
- [ ] Any residual load/unload scheduler limitation is documented if not fixed in this task.

**Notes:** Avoid user-facing API doc churn unless public behavior changes, which is not expected.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated High. NIF registrations currently have no dirty flags, while SPICE calls such as `spkobj_c` can read files and ephemeris calls may do heavier work. Planning agent should evaluate dirty CPU vs dirty IO flags per NIF. Classification: AFK.

Planning notes 2026-06-13: Current `ErlNifFunc` tables in `c_src/ephemeris.c`, `c_src/support.c`, and `c_src/time.c` use three-field registrations, so no exported function currently has dirty scheduler flags. Relevant current tests include `test/astro/cspice_concurrency_test.exs`, `test/astro/ephemeris_test.exs`, and `test/astro/time_test.exs`.

Assumptions: Keep this task focused on NIF scheduler registration and verification. Do not redesign CSPICE locking here. NIF load/unload callbacks perform CSPICE kernel work but are not `ErlNifFunc` calls; document residual risk unless explicitly expanding scope.

Implemented scheduler classification in the C NIF registration tables. `spkezr/5`, `spkez/5`, and `spkgeo/4` are dirty CPU jobs; `spkobj/1` is a dirty IO job; `str2et/1` and `utc2et/1` are dirty CPU jobs. Bounded ERFA-only conversions, short CSPICE scalar/constant helpers, conic conversions, and simple support lookups remain normal scheduler NIFs.

Added code-adjacent scheduler policy comments beside the `ErlNifFunc` tables in `c_src/ephemeris.c`, `c_src/support.c`, and `c_src/time.c`, including the residual limitation that NIF load/unload callbacks can still perform kernel I/O outside dirty scheduler registration.

Verification: red/green scheduler registration contract test added in `test/astro/native_scheduler_test.exs`; representative dirty-scheduled public API coverage added for `Astro.Ephemeris.spkezr/5` success/error and `Astro.Support.spkobj/1` success. Existing time and CSPICE concurrency tests continue to cover normal ERFA conversion and CSPICE error isolation. `mix test` and `mix check` passed.

Security review: scheduler changes are limited to registration metadata and tests; CSPICE mutex/error-reset paths are unchanged and still wrap dirty and normal CSPICE calls. `spkobj/1` path behavior is unchanged. No new logging, dependencies, shell execution, or file access surfaces were added.

Post-finalization documentation update: added an `Unreleased` changelog entry for running blocking SPICE-backed NIFs on dirty schedulers before committing the task changes.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Codex
created: 2026-06-13 13:54
---
Implementation plan added. Scope kept to dirty scheduler classification/registration and verification; CSPICE serialization redesign remains out of scope for this child task.
---

author: Codex
created: 2026-06-13 13:54
---
Planning complete; removed `needs-planning` label. Task is ready for execution.
---

author: Codex
created: 2026-06-13 13:54
---
Started implementation. Inspecting current NIF registration tables and existing tests before applying dirty scheduler classification.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

- Registered blocking/heavy SPICE-backed NIFs with dirty scheduler flags: ephemeris state retrieval and CSPICE time parsing as dirty CPU, direct SPK inspection as dirty IO.
- Left bounded ERFA-only conversions, short CSPICE scalar/constant helpers, conic conversions, and simple support lookups on normal schedulers.
- Documented the classification policy and residual load/unload callback limitation beside each `ErlNifFunc` table.
- Added regression coverage for scheduler registration metadata plus representative public API success/error behavior.

## Verification

- `mix test test/astro/native_scheduler_test.exs test/astro/ephemeris_test.exs test/astro/support_test.exs test/astro/time_test.exs test/astro/cspice_concurrency_test.exs`
- `mix format --check-formatted`
- `mix test`
- `mix check` passed; optional checks for unavailable packages were skipped by project configuration.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Every exported NIF has a reviewed scheduler classification.
- [x] #2 Dirty scheduler flags are applied only to classified SPICE-backed blocking or heavy calls.
- [x] #3 NIF build/load and representative public API behavior are verified.
- [x] #4 Security review for native scheduler, locking, file-path, dependency, and logging impacts is complete.
- [x] #5 Scheduler classification decisions and residual limitations are documented.
<!-- DOD:END -->
