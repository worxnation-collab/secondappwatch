# Combo Clock

**An unofficial concept Apple Watch companion, built for [OOWEE](https://apps.apple.com/search?term=OOWEE%20shadow%20boxing),
the Shadow Boxing & Muay Thai app.** It's a portfolio piece, not an official
OOWEE product, and it's not affiliated with or endorsed by OOWEE. It uses
OOWEE's colours as a style reference and none of its name, logo or assets.

The idea: the phone app calls combos out loud. On the wrist it can call them
**as taps**, so you can drill without looking at a screen or wearing earphones.
A 1-2 is two quick clicks and a "go"; a 1-2-3-2 is four.

## What it does

- **Home.** A Boxing / Muay Thai toggle and the workouts for each. Every row
  shows the total time, counting only the rests *between* rounds:
  2 × 2:00 + 1 × 0:30 = **4:30**. Durations always show seconds (`0:30`, `5:00`),
  never `0m` or `5m`.

  | Workout | Discipline | Rounds | Rest | Intensity | Total |
  |---|---|---|---|---|---|
  | Speed Demon | Boxing | 2 × 2:00 | 0:30 | High | 4:30 |
  | Creative Flow | Boxing, numbered combos with slips and rolls | 3 × 2:00 | 0:30 | Medium | 7:00 |
  | Eight Limbs | Muay Thai, kicks, knees and elbows | 3 × 3:00 | 1:00 | Medium | 11:00 |

- **Settings, on the watch.** Rounds, work time, rest time, intensity, and
  punch / kick countdowns. Each value is a Picker, which on watchOS opens a list
  you scroll with the Digital Crown. Edits are saved.
  - **Intensity** is combo frequency *and* length. Low calls 1–2 moves every
    6 s, Medium 2–3 every 4.5 s, High 2–4 every 3 s.
  - **A countdown** turns a round's last 10 seconds into a drill: one punch (or
    kick) per second, counted down on screen and tapped on the wrist. Muay Thai
    with both switched on alternates rounds: punches, then kicks.
- **The run.** Round number, a big countdown ring, WORK / REST, live heart rate
  and calories, and the current combo in large type: `1-2-3`, `JAB-CROSS-HOOK`,
  `TEEP`, `RIGHT KICK`. Swipe right for Pause / End, as in Apple's Workout app.
  There's no close button, so a sweaty palm can't end a round.

## Haptics are the feature

| Moment | What the wrist feels (`WKHapticType`) |
|---|---|
| Last 3 s of the get-ready, and of every rest | `.click` × 3 (one per second), then… |
| Round start | `.start` |
| A combo is called | one `.click` per move, 0.14 s apart, then `.directionUp` ("go") |
| 10 s left in the round | `.notification` |
| Countdown drill (if on) | `.click` each second, 9 → 1 |
| Bell (end of round) | `.stop` |
| Workout done | `.success` |

So a rest ends with **click, click, click, start**, and a 1-2 is
**click, click, rising tap**. Every one of these sequences is asserted exactly
in the tests.

Combos never land on top of another cue. Nothing is called in the first 2 s of
a round, within 1 s of the 10-second tap, or in the last 2.5 s before the bell.
A four-move combo's taps finish in about 0.6 s, well inside High's 3 s
interval.

## HealthKit

Each run is an `HKWorkoutSession` with an `HKLiveWorkoutBuilder`. The activity
type is `.boxing`, or `.martialArts` for Muay Thai. The workout is saved with
active energy and heart rate, and both show live on the run screen.

The session matters for more than the numbers. It keeps the app running with
the wrist down (`WKBackgroundModes: workout-processing`), which is what lets
the combo taps keep landing mid-round. If Health is unavailable or permission
is denied, the timer and haptics still run; the app says "Timer only" and saves
nothing.

## Architecture

```
RoundCore/                 Swift package, Foundation only. Builds and tests on Linux.
  Moves.swift              The moves library: punches 1–6, slip/roll, teep, kicks, knee, elbow
  ComboGenerator.swift     Seeded combo builder (by discipline + intensity)
  SeededRandom.swift       SplitMix64, so a seed means the same combos on every platform
  Workout.swift            Workout settings, the defaults, duration math and formatting
  Cue.swift                Cues → haptic patterns (Pulse + timing), as data
  WorkoutPlan.swift        The whole workout written out: segments + every cue, timestamped
  WorkoutEngine.swift      A state machine that walks the plan against an injected clock
App/                       SwiftUI watch app: screens, a 10 Hz driver, HealthKit, Pulse → WKHapticType
project.yml                XcodeGen spec (the .xcodeproj is generated, not committed)
```

**The plan is computed up front.** `WorkoutPlan` turns a workout and a seed
into a timeline:

```
2 set3 · 3 set2 · 4 set1 · 5 start1 · 7 combo · 10 combo … 25 ten · 28 combo … 35 bell1 · 47 set3 …
```

`WorkoutEngine` walks that timeline against whatever clock it's given, and
every call (`start`, `tick`, `pause`, `resume`, `end`) returns the cues it
produced. The engine owns no timer and no haptics. So the tests can assert the
exact second-by-second sequence of a workout, and check what happens when the
app is starved: after a gap, the round start and bell still fire, but nothing
more than a second stale does, because a combo tapped five seconds late can't
be thrown.

**The combo rules are ones a coach would give**, and each is a test:

- Punches alternate hands. The one exception is the double jab, 1-1.
- Slips and rolls are never first, never last, and never twice in a row.
- A Muay Thai combo always lands a kick, knee, elbow or teep. A kick goes off
  the side opposite the last punch: 1-2 → LEFT KICK, 1 → RIGHT KICK.

**Tests.** `swift test` runs 39 tests covering the moves and callouts, the
duration math and formatting, the defaults, combo generation (determinism,
pinned sequences, the rules above, library coverage), the exact timelines, the
cue patterns, and the engine (full walk, catch-up, pause, end early, status).

## Run it

```bash
cd RoundCore && swift test           # anywhere, Linux included

brew install xcodegen
xcodegen                             # writes ComboClock.xcodeproj, Info.plist, entitlements
open ComboClock.xcodeproj
```

To run it on a real watch:

1. Select the **ComboClock** scheme and your paired Apple Watch.
2. Under Signing & Capabilities, pick your team. The HealthKit entitlement comes
   from `project.yml`, so the team's App ID needs HealthKit enabled.
3. Run. The first launch asks for Health access on the home screen, not over a
   countdown.

The simulator can't play haptics or produce heart rate, so the feature itself
needs the real watch.

**CI** (`.github/workflows/ci.yml`) runs `swift test` in a Linux Swift container,
then generates the project and builds the app for the watchOS simulator on
macOS.

**TestFlight** (`codemagic.yaml`, workflow `watch-comboclock`) builds, signs and
uploads. Before the first build with HealthKit, turn on the HealthKit capability
for the App ID in the Apple Developer portal (Identifiers). An existing
provisioning profile won't carry the entitlement until it's regenerated.

## In hindsight

**I'd seed each combo slot on its own instead of drawing combos from one
running stream.** Today the generator is a single seeded sequence consumed in
order. So changing anything that alters *how many* combos come before a point
reshuffles every combo after it. That includes the intensity's interval, the
rest length, or a countdown drill that swallows slots. The tests pin
sequences, which makes that visible, but it also means a harmless timing tweak
rewrites every pinned workout. Deriving each combo from `(seed, round, slot)`
would make combo choice independent of timing. You could adjust a workout's
pacing and still get the same round you drilled yesterday, and the pinned tests
would only break when the combo *rules* change.
