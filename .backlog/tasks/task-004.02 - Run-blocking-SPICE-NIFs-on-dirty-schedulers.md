---
id: TASK-004.02
title: Run blocking SPICE NIFs on dirty schedulers
status: To Do
assignee: []
created_date: '2026-06-13 13:35'
updated_date: '2026-06-13 13:36'
labels:
  - performance
  - native
  - needs-planning
dependencies: []
references:
  - c_src/ephemeris.c
  - c_src/support.c
  - c_src/time.c
  - lib/astro/ephemeris.ex
  - lib/astro/support.ex
  - lib/astro/time.ex
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
- [ ] #1 SPICE calls with file I/O or potentially long computation are registered with appropriate dirty scheduler flags.
- [ ] #2 Normal short ERFA-only conversions remain on normal schedulers unless evidence shows they need dirty scheduling.
- [ ] #3 Tests or manual verification confirm the NIFs still load and callable functions keep their public API shape.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated High. NIF registrations currently have no dirty flags, while SPICE calls such as `spkobj_c` can read files and ephemeris calls may do heavier work. Planning agent should evaluate dirty CPU vs dirty IO flags per NIF. Classification: AFK.
<!-- SECTION:NOTES:END -->
