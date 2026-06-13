---
id: TASK-004.06
title: Clean up shared NIF utility hygiene
status: To Do
assignee: []
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 13:36'
labels:
  - maintenance
  - native
  - needs-planning
dependencies:
  - TASK-004.03
references:
  - c_src/utils.h
  - Makefile
documentation:
  - AGENTS.md
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
- [ ] #1 Shared NIF helpers avoid variable-length stack arrays or otherwise document and constrain stack allocation safely.
- [ ] #2 `utils.h` has an include guard or the shared helper implementation is split into an appropriate C source/header structure.
- [ ] #3 Native build warnings are tightened enough to catch common NIF signature and conversion mistakes without creating noisy false positives.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Low. `c_src/utils.h` defines static helper implementations without an include guard and `make_list` uses a variable-length stack array. This task depends on `TASK-004.03` because string helper shape may change there. Classification: AFK.
<!-- SECTION:NOTES:END -->
