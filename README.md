# Latch

A menu bar execution lock for macOS 14+. Apple Reminders holds the backlog; Latch only ever shows one task.

## Build & run

```bash
scripts/build-app.sh && open build/Latch.app
```

`swift test` runs the `LatchCore` suite (metadata parser, capture parser, scorer, calendar clamp, time formatting, Shutter geometry, Drift Guard ledger).
Use the bundled `.app`, not `swift run`: Reminders and Calendar access need the usage strings in `Support/Info.plist`.

## The Shutter

The menu bar shows time as geometry, not digits. The brackets close as the session runs down and snap shut at 00:00. Amber notches stack outside the bracket in overtime, one per 2 minutes. The exact clock is in the popover and the accessibility label.

## Drift Guard

When you latch, Latch pins the app you were working in. If you switch to another app for longer than the grace period (20s by default), the session is drifting:

- the Shutter's bolt blinks hollow amber once a second;
- the popover shows `DRIFTING +mm:ss` and the Refocus pill becomes `Return to <App> [⌘G]`;
- the state-dump gate summarises the drift (`Drifted 03:12 across 2 excursions`);
- the session's drift is added to `drift_sec` in the reminder's `---LATCH---` block.

Quick glances shorter than the grace period are forgiven, and opening Latch itself never counts as drift.

## Keys

| Where | Key | Action |
|---|---|---|
| Anywhere | ⌘⇧Space | Blind Capture (`~15m`, `!high`/`!1`, `#List`) |
| Selector | ↩ / ⇥ / ⌘1 | Latch / Cycle / Quick ≤15m filter |
| Selector | − / = / drag / scroll | Duration −/+ 5m on the dial |
| Focus | ⌘↩ / ⌘. / ⌘G | Complete / Unlatch / Refocus (or Return to) pinned app |
| State dump | ↩ / ⌘↩ | Log next action & unlatch / Mark done |

## Optional defaults

```bash
defaults write app.latch.Latch LatchTargetList "Work"          # only pull candidates from one list
defaults write app.latch.Latch LatchHardStop -bool YES         # at 00:00 go straight to the state dump (no overtime)
defaults write app.latch.Latch LatchDriftGraceSeconds -int 45  # Drift Guard grace period (0 = strict)
defaults write app.latch.Latch LatchDriftGuardDisabled -bool YES
```

## Layout

- `Sources/LatchCore`: pure, tested logic (`Parsers/`, `Models/`, `Logic/`).
- `Sources/Latch`: the app (`App/`, `Core/` for EventKit, FSM, hotkey and window anchor, `UI/`).
