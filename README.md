# Latch

A menu bar execution lock for macOS 14+. Apple Reminders holds the backlog; Latch only ever shows one task.

## Build & run

```bash
scripts/build-app.sh && open build/Latch.app
```

`swift test` runs the `LatchCore` suite (metadata parser, capture parser, scorer, calendar clamp, time formatting).
Use the bundled `.app`, not `swift run`: Reminders and Calendar access need the usage strings in `Support/Info.plist`.

## Keys

| Where | Key | Action |
|---|---|---|
| Anywhere | ⌘⇧Space | Blind Capture (`~15m`, `!high`/`!1`, `#List`) |
| Selector | ↩ / ⇥ / ⌘1 | Latch / Cycle / Quick ≤15m filter |
| Selector | − / = / scroll | Duration −/+ 5m |
| Focus | ⌘↩ / ⌘. / ⌘G | Complete / Unlatch / Refocus pinned app |
| State dump | ↩ / ⌘↩ | Log next action & unlatch / Mark done |

## Optional defaults

```bash
defaults write app.latch.Latch LatchTargetList "Work"   # only pull candidates from one list
defaults write app.latch.Latch LatchHardStop -bool YES  # at 00:00 go straight to the state dump (no overtime)
```

## Layout

- `Sources/LatchCore`: pure, tested logic (`Parsers/`, `Models/`, `Logic/`).
- `Sources/Latch`: the app (`App/`, `Core/` for EventKit, FSM, hotkey and window anchor, `UI/`).
