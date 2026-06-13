---
id: TASK-004.04
title: Fix Julian-date datetime rounding carry
status: In Progress
assignee:
  - Codex
created_date: "2026-06-13 13:35"
updated_date: "2026-06-13 14:14"
labels:
  - bug
  - native
  - needs-planning
dependencies: []
references:
  - c_src/time.c
  - lib/astro/time.ex
  - test/astro/time_test.exs
documentation:
  - lib/astro/time.ex
  - test/astro/time_test.exs
  - c_src/time.c
parent_task_id: TASK-004
priority: medium
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Correct the Julian-date to calendar datetime conversion so fractional-day rounding cannot produce invalid time components. The desired outcome is that edge cases near day boundaries normalize into the next date instead of returning hour 24.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 `Astro.Time.jd2dt/1` and `Astro.Time.to_datetime/1` never return or construct invalid `24:00:00.000000` values after rounding.
- [ ] #2 A focused regression test covers a Julian date whose fractional day rounds across midnight and expects the next calendar date at `00:00:00.000000`.
- [ ] #3 Existing date conversion tests continue to pass, including J2000 and datetime round-trip coverage.
- [ ] #4 Security review confirms the native-boundary change adds no new unsafe memory ownership, unchecked ERFA status path, sensitive logging, filesystem access, network access, process execution, or dependency surface.
- [ ] #5 Any non-obvious rounding-carry decision is documented near the changed code or tests; README remains unchanged unless public docs become inaccurate.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Julian-Date Datetime Rounding Carry Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Astro.Time.jd2dt/1` and `Astro.Time.to_datetime/1` normalize fractional-day rounding across midnight instead of exposing invalid `24:00:00.000000` calendar values.

**Behavior:** Converting a split Julian Date to Gregorian fields still uses ERFA as the source of calendar truth. When microsecond rounding carries the fractional day past `23:59:59.999999`, the returned date advances and time fields wrap to `00:00:00.000000`. Normal inputs and existing round-trip tolerances keep their current behavior.

**Primary Surfaces:** `c_src/time.c` native `jd2dt`; `lib/astro/time.ex` public datetime wrappers/specs; `test/astro/time_test.exs`; ERFA functions used for Julian-date/calendar conversion.

---

### Task 1: Define the Midnight-Carry Contract

**Outcome:** The expected result for Julian dates that round across midnight is explicit and reviewable.

**Scope:** Covers UTC calendar component output from `Astro.Time.jd2dt/1` and `Astro.Time.to_datetime/1`; excludes changing Julian Date representation, time-scale conversions, or SPICE ET helpers.

**Touches:** `test/astro/time_test.exs`, `lib/astro/time.ex` docs/specs as needed.

**Dependencies:** None.

**Behavior:**

- A fractional day that rounds to one full day at microsecond precision returns the next calendar date at `00:00:00.000000`.
- No public API returns hour `24`, minute `60`, second `60` from ordinary rounding carry.
- Existing acceptable ERFA error handling for invalid or unsupported dates is unchanged.

**Acceptance checks:**

- [ ] A focused regression expectation names an input near a day boundary and the normalized next-date output.
- [ ] The expected behavior is understandable from the test name or nearby public docs without reading the C implementation.

**Notes:** The failing shape comes from `eraJd2cal` returning a date plus fractional day, followed by `eraD2tf(6, fd, ...)` producing a carry to hour `24`.

### Task 2: Normalize Native `jd2dt` Calendar Output

**Outcome:** Native `jd2dt` returns valid Gregorian date/time components after microsecond rounding, including boundary carries.

**Scope:** Covers the native calendar tuple returned to Elixir; does not alter `dtf2d`, time-scale conversion NIFs, SPICE string parsing, or native scheduler behavior.

**Touches:** `c_src/time.c`; ERFA date/time conversion calls already used by this module.

**Dependencies:** Task 1.

**Behavior:**

- Normal dates keep the same year/month/day/hour/minute/second/microsecond tuple values as before.
- A rounded fractional day that reaches 24 hours is represented as the following calendar day with zeroed time-of-day fields.
- Invalid ERFA conversion statuses still surface as `badarg` through the existing Elixir error path.

**Acceptance checks:**

- [ ] `Astro.Time.jd2dt/1` returns a valid tuple for the boundary case and no component is outside `NaiveDateTime`'s valid ranges.
- [ ] The J2000 and existing round-trip tests continue to pass within their current tolerances.

**Notes:** Prefer keeping normalization inside the native boundary so both `jd2dt/1` and `to_datetime/1` receive the same valid tuple contract.

### Task 3: Verify Public Wrapper Behavior

**Outcome:** `Astro.Time.to_datetime/1` can construct a `NaiveDateTime` for the boundary case and preserves current public behavior elsewhere.

**Scope:** Covers public Elixir wrappers over `jd2dt`; excludes introducing new public APIs or changing the split Julian Date type.

**Touches:** `lib/astro/time.ex`, `test/astro/time_test.exs`.

**Dependencies:** Task 2.

**Behavior:**

- `to_datetime/1` returns a normal ISO `NaiveDateTime` at the next date's midnight for the boundary case.
- Public specs remain aligned with the native tuple shape.
- Existing doctests and time conversion tests continue to describe the API accurately.

**Acceptance checks:**

- [ ] Boundary coverage includes the public `to_datetime/1` path or otherwise proves it consumes the normalized `jd2dt/1` tuple safely.
- [ ] `mix test test/astro/time_test.exs` passes.

**Notes:** The Elixir layer currently constructs the struct directly, so invalid native time fields can become a public wrapper failure.

### Task 4: Security and Native-Boundary Review

**Outcome:** The change does not weaken native input validation, memory safety, dependency trust, or operational diagnosability.

**Scope:** Reviews only surfaces touched by this task: numeric NIF arguments, ERFA status handling, tuple construction, logging/error behavior, and build/test implications.

**Touches:** `c_src/time.c`, `lib/astro/time.ex`, tests covering the changed behavior.

**Dependencies:** Tasks 1-3.

**Behavior:**

- Numeric inputs still rely on existing NIF argument checks and ERFA status checks.
- No secrets, paths, external network calls, process execution, or new dependencies are introduced.
- Errors and unexpected native failures continue to include enough context through existing `badarg`/exception behavior without logging sensitive data.

**Acceptance checks:**

- [ ] Review confirms no new unsafe memory ownership, unchecked ERFA status, or out-of-range tuple construction path was introduced.
- [ ] Review confirms no new logging of sensitive data, filesystem access, network access, process execution, or dependency supply-chain surface was added.

**Notes:** This is a native C/NIF hardening task; security review should focus on preserving the existing boundary guarantees while fixing the rounding bug.

### Task 5: Document Decisions Near the Code

**Outcome:** Any non-obvious rounding-carry decision is documented where future maintainers will look first.

**Scope:** Covers code-adjacent explanation for the normalization contract and test intent; excludes broad README changes unless the public API documentation becomes inaccurate.

**Touches:** `c_src/time.c`, `lib/astro/time.ex`, `test/astro/time_test.exs`, README only if public examples or guarantees need adjustment.

**Dependencies:** Tasks 1-4.

**Behavior:**

- The final code or tests make clear why midnight carry is normalized instead of returning hour `24`.
- Public documentation remains accurate for split Julian Dates and datetime conversion.
- Implementation notes capture the chosen approach and any rejected alternatives that matter for future native work.

**Acceptance checks:**

- [ ] Code-adjacent docs, comments, or test names explain the boundary behavior without excessive implementation detail.
- [ ] Task notes summarize the final decision, compatibility impact, and verification performed.

**Notes:** Prefer small local documentation over repo-level docs for this narrow bug fix.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Provenance: review finding rated Medium. `c_src/time.c` computes date with `eraJd2cal` and then rounds fractional day with `eraD2tf(6, ...)`, which can carry to hour 24 near midnight. `lib/astro/time.ex` then builds `NaiveDateTime`, which cannot represent hour 24. Classification: AFK.

Planning context gathered 2026-06-13: `c_src/time.c` native `jd2dt` currently calls `eraJd2cal(jd1, jd2, ...)` and then `eraD2tf(6, fd, ...)`; near midnight this can produce `ihmsf[0] == 24` for the date returned before rounding. `lib/astro/time.ex` exposes both `jd2dt/1` and `to_datetime/1`; `to_datetime/1` directly builds `%NaiveDateTime{}` from the native tuple, so the invariant should be fixed at the native tuple boundary. Existing focused tests live in `test/astro/time_test.exs`. Assumptions: keep split Julian Date representation unchanged; no new public API; no new dependencies; no broad README update expected for this narrow bug fix. Unresolved questions: none.

<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->

author: Codex
created: 2026-06-13 14:14

---

## Implementation plan saved. Scope is limited to native `jd2dt` midnight carry normalization, public wrapper regression coverage, security review, and local documentation of the rounding decision.

<!-- COMMENTS:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [ ] #1 Implementation plan is stored on the Backlog task before code changes.
- [ ] #2 Boundary regression and existing time conversion tests pass.
- [ ] #3 Native-boundary security review is completed and recorded in task notes.
- [ ] #4 Relevant code-adjacent documentation or test naming captures the rounding-carry decision.
- [ ] #5 Modified files and final verification summary are recorded on the task when implementation completes.
<!-- DOD:END -->
