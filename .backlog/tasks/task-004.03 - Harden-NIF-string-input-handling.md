---
id: TASK-004.03
title: Harden NIF string input handling
status: Done
assignee:
  - Codex
created_date: "2026-06-13 13:35"
updated_date: "2026-06-13 14:12"
labels:
  - security
  - native
  - needs-planning
dependencies: []
references:
  - c_src/utils.h
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
documentation:
  - c_src/utils.h
  - lib/astro/time.ex
  - lib/astro/support.ex
  - lib/astro/ephemeris.ex
modified_files:
  - c_src/utils.h
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - lib/astro/time.ex
  - lib/astro/support.ex
  - lib/astro/ephemeris.ex
  - test/astro/native_string_boundary_test.exs
  - CHANGELOG.md
parent_task_id: TASK-004
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Make binary-to-C-string conversion safe at the NIF boundary. The desired outcome is that native string arguments reject embedded NUL bytes, avoid unbounded allocation, and cannot overflow size arithmetic before allocation.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 String arguments passed to native code reject embedded NUL bytes before CSPICE can observe truncated values.
- [x] #2 String allocation has explicit, documented size limits appropriate for paths, body names, frames, time strings, time-system names, aberration corrections, and kernel item names.
- [x] #3 Allocation size arithmetic is checked before allocation, and invalid, allocation-unsafe, or oversized inputs return a controlled failure without leaks.
- [x] #4 Regression tests cover representative embedded-NUL and oversize inputs across the affected public NIF surfaces while preserving existing valid-call behavior.
- [x] #5 Security review and code-adjacent documentation capture the final limits, failure behavior, and residual compatibility considerations.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Harden NIF String Input Handling Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native string arguments are safe before they reach CSPICE or ERFA-adjacent NIF code.

**Behavior:** Public functions that accept Elixir binaries as native strings reject embedded NUL bytes instead of letting C APIs see truncated values. Each native string category has an explicit maximum length, and oversized or allocation-unsafe inputs fail in a controlled way. Existing successful SPICE calls keep their public return shapes and scheduler behavior.

**Primary Surfaces:** `c_src/utils.h`; string call sites in `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`; NIF load-time kernel path handling; public docs and tests under `lib/astro/*` and `test/astro/*`.

---

### Task 1: Define Native String Contracts

**Outcome:** Every string crossing the NIF boundary has a named category, maximum length, and failure contract.

**Scope:** Include body names/IDs-as-strings, reference frames, aberration corrections, time strings, time-system names, SPK/kernel paths, and kernel-pool item names. Exclude numeric/list validation and CSPICE result-buffer sizing.

**Touches:** `c_src/utils.h`; call sites in `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`; NIF load callback in `c_src/utils.h`.

**Dependencies:** None.

**Behavior:**

- The implementation has explicit limits for each native string category instead of accepting caller-controlled binary sizes.
- Limits are conservative enough for documented SPICE usage in this library and are recorded near the boundary that enforces them.
- Empty strings, embedded NUL bytes, oversized strings, and non-binaries have clear failure behavior.

**Acceptance checks:**

- [ ] All current `load_string` call sites are classified by string category.
- [ ] The final maximum lengths are visible to maintainers and tied to the category they protect.
- [ ] Public failure behavior for invalid native strings is consistent with existing bad-argument behavior or intentionally documented as a controlled error.

**Notes:** Exact maximum values should be chosen from CSPICE expectations and this library's public docs during implementation, then documented with the rationale.

### Task 2: Enforce Safe Binary-to-C-String Loading

**Outcome:** The shared NIF string loader rejects unsafe binaries and cannot overflow allocation sizing.

**Scope:** Replace the unsafe unbounded copy behavior at the shared helper boundary. Include embedded NUL scanning, maximum length checks, and checked size arithmetic before allocation. Exclude broader memory allocator refactors.

**Touches:** `c_src/utils.h` primarily; all first-party C files that include it indirectly.

**Dependencies:** Task 1.

**Behavior:**

- Embedded NUL bytes are rejected before a value can be passed to a C API expecting a NUL-terminated string.
- Allocation size is checked before allocation, including the terminator byte.
- Allocation failure, invalid input type, embedded NUL, and oversize input all return controlled failures and do not leak partially allocated strings.

**Acceptance checks:**

- [ ] A binary containing `\0` cannot be accepted by the native string conversion path.
- [ ] A binary at or beyond each configured limit cannot trigger unchecked allocation or arithmetic wraparound.
- [ ] Cleanup paths remain safe when one of several string arguments fails after earlier strings were allocated.

**Notes:** Preserve existing C cleanup style and do not widen the change into unrelated CSPICE synchronization behavior.

### Task 3: Apply Category-Specific Limits at Call Sites

**Outcome:** Each NIF call site uses the appropriate native string contract for its arguments.

**Scope:** Cover ephemeris strings, support/body/kernel strings, time parser strings, time-system strings, and load-time kernel paths. Exclude adding new public APIs.

**Touches:** `c_src/ephemeris.c`, `c_src/support.c`, `c_src/time.c`, load callback in `c_src/utils.h`.

**Dependencies:** Tasks 1 and 2.

**Behavior:**

- `spkezr`, `spkez`, and `spkgeo` distinguish body/frame/aberration string limits where applicable.
- `bodn2c`, `spkobj`, `bodvcd`, and `bodvrd` use limits appropriate to body names, file paths, and kernel-pool item names.
- `str2et`, `utc2et`, and `unitim` use limits appropriate to parser input and SPICE time-system names.
- NIF load-time kernel path decoding is covered by the same safety properties as runtime calls.

**Acceptance checks:**

- [ ] No first-party `load_string` usage remains unbounded or category-ambiguous.
- [ ] Valid existing examples and tests continue to work with normal body names, frames, corrections, time strings, and kernel paths.
- [ ] Invalid string failures occur before CSPICE receives truncated or oversized input.

**Notes:** Keep stable public NIF arities and return shapes for successful calls.

### Task 4: Add Regression Coverage

**Outcome:** Tests prove the security-sensitive string boundary behavior and protect existing success paths.

**Scope:** Add focused ExUnit coverage for representative string-accepting APIs across time, support, and ephemeris modules. Include embedded NUL and oversize cases. Exclude exhaustive CSPICE parser semantics.

**Touches:** `test/astro/time_test.exs`, `test/astro/support_test.exs`, `test/astro/ephemeris_test.exs`, or a dedicated native string boundary test if clearer.

**Dependencies:** Tasks 2 and 3.

**Behavior:**

- Embedded NUL in public binary arguments raises or returns the documented controlled failure instead of succeeding with a truncated value.
- Oversized strings are rejected without relying on CSPICE errors or large allocations.
- Existing valid examples still pass, including dirty scheduled SPICE calls.

**Acceptance checks:**

- [ ] Tests cover embedded NUL rejection for at least one body/frame/path/time-string path and enough representative call sites to prove shared helper coverage.
- [ ] Tests cover oversize rejection for each distinct limit category or justify representative shared-helper coverage in notes/docs.
- [ ] Relevant test commands pass after recompiling the NIF.

**Notes:** Prefer tests that exercise public Elixir APIs so reviewers can verify external behavior without binding to helper internals.

### Task 5: Security Review

**Outcome:** The final change is reviewed against native-boundary security risks introduced or touched by this work.

**Scope:** Review string parsing, allocation, logging, file path handling, CSPICE calls, dependency trust, and cleanup behavior. Exclude unrelated scheduler policy and numeric conversion hardening unless changed by this task.

**Touches:** Changed C files, affected tests, and any public docs updated by the implementation.

**Dependencies:** Tasks 1-4.

**Behavior:**

- No embedded NUL, path, parser, or kernel item string can bypass the chosen NIF validation.
- No checked failure path logs sensitive full user input unnecessarily; operational logs still retain enough context for load-time kernel failures.
- Native memory ownership remains clear across all success and failure paths.

**Acceptance checks:**

- [ ] Review confirms arithmetic checks cover terminator allocation and cannot wrap before `malloc`.
- [ ] Review confirms failure paths free earlier allocations and do not call CSPICE with invalid strings.
- [ ] Review confirms logging does not add sensitive runtime input exposure beyond existing load/unload diagnostics.

**Notes:** Record any residual risk or deliberately accepted compatibility tradeoff in implementation notes.

### Task 6: Document Final Decisions

**Outcome:** Maintainers can understand the enforced limits, failure behavior, and reason for the boundary hardening without reading the whole diff.

**Scope:** Prefer code-adjacent documentation in native helpers and public module docs/typespec notes where behavior is externally visible. Use repo-level docs only if final decisions span modules in a way code-adjacent docs cannot explain cleanly.

**Touches:** `c_src/utils.h`; possibly `lib/astro/time.ex`, `lib/astro/support.ex`, `lib/astro/ephemeris.ex`; optional `docs/` file only if justified.

**Dependencies:** Tasks 1-5.

**Behavior:**

- Final string categories and limits are documented close to the enforcing code.
- Public docs mention invalid string failure behavior where it affects users.
- Security and compatibility decisions are captured for future NIF additions.

**Acceptance checks:**

- [ ] Code-adjacent docs explain why embedded NULs and oversize strings are rejected.
- [ ] Public docs or notes identify any user-visible limit that can affect normal callers.
- [ ] Backlog task notes summarize final decisions and any rejected alternatives after implementation.

**Notes:** Keep docs concise; avoid duplicating CSPICE manuals except where needed to justify limits.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Provenance: review finding rated Medium. `load_string` in `c_src/utils.h` accepts arbitrary binaries, copies them to C strings, and can silently truncate at embedded NUL when passed to CSPICE. It also allocates based on caller-controlled binary size. Classification: AFK.

Planning context gathered 2026-06-13: the current shared `load_string` in `c_src/utils.h` inspects any binary, allocates `bin.size + 1`, copies bytes, and appends a terminator. It is used by runtime calls in `c_src/ephemeris.c`, `c_src/support.c`, and `c_src/time.c`, plus load-time kernel path decoding in `c_src/utils.h`. Existing tests cover valid time/support/ephemeris paths and invalid types, but not embedded NUL or oversize strings. No `docs/` files currently exist in the repo. Assumption: implementation should preserve public NIF arities and successful return shapes; controlled invalid-string failures may follow the existing badarg/ArgumentError pattern unless implementation finds a stronger local convention. Unresolved questions: none requiring user input before implementation; implementer must choose exact max lengths from CSPICE expectations and this library's documented usage, then record rationale.

Execution started. Reviewed approved plan and Backlog execution guidance. No blocking plan concerns found; implementation will keep public NIF arities and successful return shapes stable, classify all current native string inputs by category, and use existing bad-argument failure behavior for invalid native strings unless code inspection shows a stricter local convention.

Implementation complete. Final native string limits, in bytes excluding terminator: body/body-ID string 36; frame 26; aberration correction 5; kernel/SPK path 255; kernel-pool item 32; general `str2et` time string 256; `utc2et` UTC string 80; `unitim` time-system name 5. Non-binaries, empty binaries, embedded NUL bytes, and oversized binaries now fail through the existing badarg/`ArgumentError` path before CSPICE is called. Load-time kernel paths use the same path limit and NUL/size validation.

Security review completed. `load_string` rejects embedded NULs with `memchr` before copying, checks `bin.size > SIZE_MAX - 1` before allocating the terminator byte, allocates exactly `bin.size + 1`, and only writes the output pointer after successful allocation/copy. Multi-string call sites still initialize pointers to NULL and use existing cleanup labels, so earlier allocations are freed if a later string fails. No CSPICE call receives a rejected string. Logging does not expose new runtime string payloads; load-time kernel decode failure remains generic, while existing configured-path CSPICE load failures still include the configured path for diagnostics. Residual compatibility tradeoff: some invalid empty or oversized strings now raise `ArgumentError` instead of returning CSPICE error tuples; documented valid calls are unchanged.

Changelog updated under Unreleased to mention native string input hardening before commit.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Hardened native string decoding by adding category-specific byte limits and rejecting empty, embedded-NUL, and oversized binaries before C string allocation or CSPICE calls. Updated all first-party string call sites and load-time kernel paths to use explicit categories, documented the limits in native and public module docs, and added public regression coverage for NUL and oversize rejection across time, support, and ephemeris APIs. Verified with `mix compile --force`, focused wrapper tests, `mix test`, and `mix check`.

<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [x] #1 Relevant NIF code compiles cleanly after string-boundary changes.
- [x] #2 Existing valid SPICE/ERFA wrapper tests continue to pass.
- [x] #3 Regression tests demonstrate embedded NUL rejection and oversize handling for affected public surfaces.
- [x] #4 Security review for native string input handling is completed and recorded in task notes.
- [x] #5 Final string limits and failure behavior are documented close to the enforcing code.
<!-- DOD:END -->
