---
id: TASK-004.05
title: Remove or surface fixed SPICE support capacity limits
status: To Do
assignee: []
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 13:36'
labels:
  - bug
  - native
  - needs-planning
dependencies: []
references:
  - c_src/support.c
  - lib/astro/support.ex
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
- [ ] #1 `spkobj/1` does not silently depend on an undocumented 1000-ID native result cap.
- [ ] #2 `bodvcd/2` and `bodvrd/2` do not silently depend on an undocumented 16-value native result cap.
- [ ] #3 Tests or documented examples cover normal results and capacity-exceeded behavior if a cap remains.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Low. `c_src/support.c` uses `SPICEINT_CELL(ids, 1000)` for `spkobj` and `SpiceDouble values[16]` for `bodvcd`/`bodvrd`; valid larger kernel data may fail in undocumented ways. Classification: AFK.
<!-- SECTION:NOTES:END -->
