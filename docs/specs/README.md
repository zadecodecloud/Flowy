# NotchFlow behaviour specs

These are the clean-room handover documents for the rewrite in
[`../REWRITE_PLAN.md`](../REWRITE_PLAN.md).

- **The spec side** writes them from the old app's behaviour.
- **The build side** implements from them alone.

## Rules for every spec

- Describe what the user sees and what the app does: states, timings, sizes, settings and
  their defaults, edge cases, and acceptance checks.
- No source code, pseudo-code, type, function, file or preference-key names from the old
  project, and no copied UI text. Describe a label by its meaning, for example "the battery
  percentage and a charging indicator".
- Describe system or private APIs by purpose only, for example "detect when the screen
  locks". The build side finds its own way to do it.
- Numbers (points, seconds, percentages) are facts about the behaviour and may be given.
  "≈" marks a value that only needs to look right.
- Each spec ends with **Acceptance checks**: observable, testable statements.
- Before handover, run the leak check and fix every flagged line:

  ```bash
  python3 -I scripts/spec-leak-check.py <extracted upstream tree> docs/specs
  ```

## Template

```markdown
# <Area>

## Purpose
## Behaviour
## States and transitions
## Settings
| Setting | Default | Effect |
## Timings and sizes
## Edge cases
## Out of scope
## Acceptance checks
```

## Index

| # | Spec | Status |
|---|---|---|
| 01 | [Notch shell](01-notch-shell.md) | leak-checked |
| 02 | [Content engine](02-content-engine.md) | leak-checked |
| 03 | [Glass and appearance](03-glass-appearance.md) | leak-checked |
| 04 | [Media and lyrics](04-media-lyrics.md) | leak-checked |
| 05 | [Lock screen](05-lock-screen.md) | leak-checked |
| 06 | [Lock-screen music panel](06-lock-screen-music.md) | leak-checked |
| 07 | [File tray and drag-and-drop](07-file-tray.md) | leak-checked |
| 08 | [Mirror](08-mirror.md) | leak-checked |
| 09 | [HUD](09-hud.md) | leak-checked |
| 10 | [System status](10-system-status.md) | leak-checked |
| 11 | [Timer](11-timer.md) | leak-checked |
| 12 | [Calendar](12-calendar.md) | leak-checked |
| 13 | [Downloads](13-downloads.md) | leak-checked |
| 14 | [Screenshots and recording](14-screenshots-recording.md) | leak-checked |
| 15 | [Settings and onboarding](15-settings-onboarding.md) | leak-checked |
| 16 | [Updates and licensing](16-updates-licensing.md) | leak-checked |
