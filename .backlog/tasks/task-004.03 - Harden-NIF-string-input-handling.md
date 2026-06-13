---
id: TASK-004.03
title: Harden NIF string input handling
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
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make binary-to-C-string conversion safe at the NIF boundary. The desired outcome is that native string arguments reject embedded NUL bytes, avoid unbounded allocation, and cannot overflow size arithmetic before allocation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 String arguments passed to native code reject embedded NUL bytes instead of truncating silently in C APIs.
- [ ] #2 String allocation has explicit size limits appropriate for paths, body names, frames, time strings, and kernel item names.
- [ ] #3 Allocation size arithmetic is checked before `malloc`, and invalid or oversized inputs return a controlled error.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Medium. `load_string` in `c_src/utils.h` accepts arbitrary binaries, copies them to C strings, and can silently truncate at embedded NUL when passed to CSPICE. It also allocates based on caller-controlled binary size. Classification: AFK.
<!-- SECTION:NOTES:END -->
