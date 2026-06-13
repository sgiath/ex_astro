---
id: TASK-004.04
title: Fix Julian-date datetime rounding carry
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
  - c_src/time.c
  - lib/astro/time.ex
  - test/astro/time_test.exs
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
- [ ] #2 A focused regression test covers a Julian date whose fractional day rounds across midnight.
- [ ] #3 Existing date conversion tests continue to pass.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provenance: review finding rated Medium. `c_src/time.c` computes date with `eraJd2cal` and then rounds fractional day with `eraD2tf(6, ...)`, which can carry to hour 24 near midnight. `lib/astro/time.ex` then builds `NaiveDateTime`, which cannot represent hour 24. Classification: AFK.
<!-- SECTION:NOTES:END -->
