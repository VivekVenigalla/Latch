# Latch

A menu bar execution lock for macOS 14+. Apple Reminders holds the backlog; Latch only ever shows one task.

## Build & run

```bash
scripts/build-app.sh && open build/Latch.app
```

`swift test` runs the `LatchCore` suite (metadata parser, capture parser, scorer, calendar clamp, time formatting, Deadbolt geometry and token labels, Drift Guard ledger).
Use the bundled `.app`, not `swift run`: Reminders and Calendar access need the usage strings in `Support/Info.plist`.

## The Deadbolt

The menu bar token is a deadbolt: a housing, a bolt and a keeper. While you're latched the bolt slides toward the keeper as time is spent, and at 00:00 it's seated. Beside it is a coarse time (`18m`, switching to seconds in the final minute, `+2m` in overtime) and the task title. When you latch, the bolt throws home and springs back, like setting a real latch.

It's a template image with a native title, so it tints like system icons on any menu bar. Paused and drifting sessions draw the bolt hollow.

### Keeping it visible

macOS hides menu bar items that don't fit, and on notched MacBooks they disappear behind the notch.

- **⌘-drag the item** to where you want it (for example, nearer the clock). Latch remembers the position.
- When the full item is hidden, Latch **collapses to the bolt and time**, then retries the full width when your displays change and every 5 minutes.
- On macOS 26, also check **System Settings → Menu Bar** that Latch is allowed in the menu bar.

**Right-click** the item for a native menu: status, Open, Complete, Unlatch, Refocus, Capture and Quit.

## Drift Guard

When you latch, Latch pins the app you were working in. If you switch to another app for longer than the grace period (20s by default), the session is drifting:

- the Deadbolt's bolt blinks hollow once a second (amber in the popover);
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
