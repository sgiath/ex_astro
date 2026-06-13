---
id: TASK-004.01
title: Serialize CSPICE NIF access
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
- [ ] #1 Concurrent calls to SPICE-backed NIFs cannot interleave CSPICE calls with `failed_c`, `getmsg_c`, or `reset_c` error handling.
- [ ] #2 The NIF load/unload lifecycle initializes and releases any synchronization primitive safely.
- [ ] #3 A regression test or stress check exercises concurrent SPICE-backed calls without inconsistent errors or crashes.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated High. CSPICE keeps global kernel and error state; BEAM may execute NIFs concurrently on scheduler threads. Planning agent should inspect `c_src/utils.h`, `c_src/ephemeris.c`, `c_src/support.c`, and SPICE-backed functions in `c_src/time.c`. Classification: AFK.
<!-- SECTION:NOTES:END -->
