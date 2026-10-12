# Pace Calculator — Plan

## Goals

A fast, spinner-driven pace calculator for runners, plus a race-watching mode.

User stories:

1. Training: what time should I run 400m in to hold 5:45/mi? → **1:25.7**
2. Training: I ran 800m in 2:45 — what pace was that? → **5:31.9/mi** (3:26.3/km)
3. Watching: the leaders went through 5k in 14:34 — what's their finish time at that pace? → **2:02:55.7**
4. Watching: follow a race split by split and see how the pace and projected finish are changing.

## Global behavior

- **Unit toggle (mi / km)** for pace, speed, and custom distances. Persisted across launches (`@AppStorage`).
- **Race in progress** is persisted (see Race tab).
- **Tenths of a second** shown on all times and paces.
- **Input:** wheel spinners on iPhone/iPad (no keyboard anywhere). Minutes, seconds and tenths wheels wrap around (59 → 00) like the system timer. Numeric text fields on macOS.
- **Last tab** (Calculator / Race) is remembered, so a race in progress comes straight back on launch.

## Tab 1 — Calculator

Layout, top to bottom:

1. **Unit toggle** mi / km
2. **Three rows: Distance, Time, Pace.** Pace also shows the other unit and speed in mph or km/h (for treadmills).
3. **Splits table**: time at the current pace for every preset distance. The current distance is highlighted. Tapping a row moves to that distance at the current pace.

**Editing:** tapping a row opens an input panel at the bottom of the screen, where a keyboard would appear (inline in the left column on iPad/macOS). Tapping another row switches the panel; tapping the same row or Done closes it.

- **Distance:** preset buttons; "Custom" adds whole + hundredths wheels in km or mi below them.
- **Time:** h : mm : ss . t wheels.
- **Pace:** m : ss . t wheels, per mi or km.

**Which value is calculated:** distance is always an input. Of time and pace, whichever was set most recently stays fixed and the other is calculated (shown in the accent colour with a "calculated" label). Changing distance recalculates the non-fixed one. Tapping a split row fixes the pace. This rule lives in `PaceCore/Calculation.swift`.

- Story 1: set pace 5:45, pick 400m → time 1:25.7.
- Story 2: pick 800m, set time 2:45 → pace 5:31.9/mi.
- Story 3: pick 5k, set time 14:34 → marathon row shows 2:02:55.7.

**Preset distances:** 200m, 400m, 800m, 1000m, 1500m, 1mi, 3000m, 5k, 10k, 15k, 10mi, half marathon, marathon, 50k.

## Tab 2 — Race

The user picks a race, then records the elapsed time at each split as the race goes on.

### Races and split points (cumulative from start)

| Race | Split options | Split points |
|---|---|---|
| 800m | — | 200, 400, 600, 800 |
| 1500m | — | 300, 700, 1100, 1500 |
| Mile | — | 409.344, 809.344, 1209.344, 1609.344 |
| 3000m | — | 200, 600 … 2600, 3000 |
| 5000m | — | 200, 600 … 4600, 5000 |
| 10,000m | — | 400, 800 … 10,000 |
| 5k road | 1k / mile | 1k…5k · or 1mi, 2mi, 3mi, finish |
| 10k road | 1k / mile | 1k…10k · or 1mi…6mi, finish |
| Half marathon | 5k / mile | 5k, 10k, 15k, 20k, finish · or 1mi…13mi, finish |
| Marathon | 5k / mile | 5k…40k (+ half), finish · or 1mi…26mi, finish |

Steeplechase is out of scope.

### Multiple races

Several races can be tracked at once (e.g. men's and women's marathons running simultaneously). Each is fully independent: its own race type, split type, and recorded splits.

- **Add race** → pick race + split type + a **label** chosen from chips (Men / Women / none), so no keyboard is needed. A custom name is optional (keyboard is OK for text). Default title: "Marathon · Men".
- **Switching:** a segmented control across the top of the Race tab when 2–3 races exist (one tap to switch); a dropdown menu for 4+. When all races are the same kind, segments show just the label (Men / Women).
- **Delete** the selected race from the Race tab's "…" menu, with a confirmation. Finished races stay until deleted.
- Individual splits can be cleared by swiping a row in the split list.

### Flow (per race)

- Split list appears with the next split point selected.
- Time wheels for the current split are **prefilled with the even-pace projection** (rounded to tenths, so a recorded split is exactly what's on screen), so the user usually only nudges seconds. Track races hide the hours wheel.
- **Record** → stores the split and moves on to the next split point. Splits can be skipped (missed the 10k → enter the 15k), and the last split can be edited or undone.

### Persistence

All races (type, split type, label, recorded splits, selected split point) plus which race is selected are saved as `Codable` JSON in Application Support after every change and restored on launch. Closing the app, the app being killed in the background, or a reboot mid-race loses nothing.

### Display per recorded split

- Elapsed time
- **Segment time** since the previous recorded split
- Segment pace. Track races show this as a per-400 lap equivalent (e.g. "62.4 / 400"), so the 300m and 409m first segments are comparable. Road races show it as pace per mi/km.

### Projections (after each recorded split)

- **Finish at average pace** (whole race so far)
- **Finish at last-segment pace** (elapsed + remaining distance × last segment pace)
- Projected elapsed time at each remaining split point (at average pace)

## Platforms

- **iPhone:** primary target. Single column.
- **iPad:** same app. Regular width → input on the left, table on the right.
- **macOS:** native SwiftUI (not Catalyst). Number fields instead of wheels; same two-column layout as iPad.
- **Android:** native Kotlin + Jetpack Compose app in `android/` (see below).

Minimums: iOS 17, macOS 14.

## Android

- `android/core`: pure Kotlin port of PaceCore (no Android dependencies). Its tests run the same `PaceCore/Tests/PaceCoreTests/fixtures.json` vectors as iOS, plus ports of the iOS unit tests.
- `android/app`: Compose UI mirroring iOS. Wheels are the platform `NumberPicker` (wrap-around for minutes/seconds/tenths). Unit and last tab in SharedPreferences; races in `races.json` in app storage, written after every change.
- Differences from iOS: a recorded split is cleared with long-press (or the Clear button) rather than swipe; single-column layout on tablets.
- Build: `cd android && ./gradlew assembleRelease` (needs `JAVA_HOME` set to a JDK 17+, e.g. Android Studio's bundled one). The release APK is signed with the local debug key for sharing with testers; set up a real keystore before any Play Store release.

## Architecture

```
pace-calculator/
  project.yml                 # XcodeGen spec → PaceCalculator.xcodeproj (generated, gitignored)
  PaceCore/                   # local Swift package, pure logic, no UI
    Sources/PaceCore/
      Distance.swift          # meters-based; presets; mi/km conversions
      RaceTime.swift          # seconds (Double) ↔ h:m:s.t; rounding/formatting
      Pace.swift              # pace/speed math, projections
      Race.swift              # race definitions, split schedules, segment + projection math
    Tests/PaceCoreTests/      # user stories, rounding edge cases, split schedules, fixtures.json
  PaceCalculator/             # SwiftUI app (iOS + macOS, one target)
    App.swift
    Calculator/               # CalculatorView, DistancePicker, SplitsTable
    Race/                     # RaceView, SplitEntry, SplitList
    Components/               # DurationWheel (UIPickerView wrapper on iOS, TextFields on macOS), UnitToggle
```

Notes:

- Multi-column wheels use a `UIPickerView` with multiple components wrapped in `UIViewRepresentable`. Side-by-side SwiftUI `.wheel` pickers have known hit-testing glitches.
- Rounding: values are stored as full-precision seconds and only rounded to tenths when displayed.
- Distances: mile = 1609.344m, half = 21097.5m, marathon = 42195m.

## Testing

- `swift test` in `PaceCore`: user stories 1–3, the race-mode segment and projection math, split schedules (e.g. mile first split = 409.344m, 5000m has 13 splits), and race state encode/decode round-trip.
- iOS Simulator run with screenshots of both tabs on iPhone and iPad sizes; macOS build run.

## Milestones

1. Scaffolding (XcodeGen, package, app target) + PaceCore with tests passing
2. Calculator tab (iPhone)
3. Race tab (iPhone)
4. iPad + macOS adaptations
5. Install on your devices (personal team signing via a free Apple ID; builds expire after 7 days)

## Out of scope (for now)

History, favorites, widgets, Watch app, App Store distribution, steeplechase.
