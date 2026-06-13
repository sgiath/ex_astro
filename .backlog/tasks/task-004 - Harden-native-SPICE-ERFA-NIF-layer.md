---
id: TASK-004
title: Harden native SPICE/ERFA NIF layer
status: To Do
assignee: []
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 13:36'
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
  - lib/astro/time.ex
  - lib/astro/ephemeris.ex
  - lib/astro/support.ex
documentation:
  - AGENTS.md
  - README.md
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Track the native-code hardening follow-up from the C/NIF review of ex_astro. The outcome is a safer and more predictable SPICE/ERFA NIF boundary across concurrency, scheduler behavior, input validation, date conversion edge cases, and utility hygiene.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All review findings from the June 13, 2026 C/NIF review are represented by child tasks or explicitly closed as not applicable.
- [ ] #2 Child tasks can be planned and implemented independently without relying on this conversation history.
- [ ] #3 The parent remains a tracking task and is not used for implementation work directly.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: created from the assistant's C/NIF review of `c_src/` on 2026-06-13 at the user's request. Source findings covered CSPICE global-state races, dirty scheduler usage, NIF string validation, Julian-date rounding carry, fixed native result capacities, and shared utility hygiene. Classification: parent tracking task; child tasks are AFK planning/implementation slices.
<!-- SECTION:NOTES:END -->
