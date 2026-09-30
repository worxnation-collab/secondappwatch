# Combo Clock

**An unofficial concept Apple Watch companion, built for [OOWEE](https://apps.apple.com/search?term=OOWEE%20shadow%20boxing),
the Shadow Boxing & Muay Thai app.** It's a portfolio piece, not an official
OOWEE product, and it's not affiliated with or endorsed by OOWEE. It uses
OOWEE's colours as a style reference and none of its name, logo or assets.

The idea: the phone app calls combos out loud. On the wrist it can call them
**as taps**, so you can drill without looking at a screen or wearing earphones.
A 1-2 is two quick clicks and a "go"; a 1-2-3-2 is four.

## What it does

The watch app is **boxing only**, done properly. Muay Thai (teep, kicks, knees,
elbows, kick countdowns, its own default workout) is fully built and tested in
RoundCore and is one filter away from coming back to the UI. It's held back so
the watch shows one discipline with nothing half-finished.

- **Home.** The boxing workouts and **My Combos**. Every row shows the total
  time, counting only the rests *between* rounds:
  2 × 2:00 + 1 × 0:30 = **4:30**. Durations always show seconds (`0:30`,
  `5:00`), never `0m` or `5m`.

  | Workout | Style | Rounds | Rest | Intensity | Total |
  |---|---|---|---|---|---|
  | Speed Demon | Called by name, with a punch countdown | 2 × 2:00 | 0:30 | High | 4:30 |
  | Creative Flow | Numbered: body shots and defense mixed in | 3 × 2:00 | 0:30 | Medium | 7:00 |

- **The moves.** Punches 1–6; body shots 1B–4B; evasions slip, roll, duck, pull
  and parry; and a pivot to get out.
- **Settings, on the watch.** Each value is a Picker, which on watchOS opens a
  list you scroll with the Digital Crown. Edits are saved.
  - Rounds, work time and rest time.
  - **Intensity** is combo frequency *and* length. Low calls 1–2 moves every
    6 s, Medium 2–3 every 4.5 s, High 2–4 every 3 s.
  - **Combos** comes from the generator or from My Combos.
  - **Defense** and **Body shots** switch those moves on in generated combos.
  - **Call as** numbers (`1-3B-2`) or names (`JAB-BODY HOOK-CROSS`).
  - **A punch countdown** turns a round's last 10 seconds into one punch per
    second, counted down on screen and tapped on the wrist.
- **My Combos.** Build your own on the watch: tap moves in order, **Feel it**
  to get the exact taps a round will give you, then save. Tap any saved combo to
  feel it again. Set a workout's Combos to "My combos" and the round calls
  yours, in random order, never the same one twice in a row. The app starts you
  with 1-2, 1-1-2 and 1-2-3-2.
- **The run.** Round number, a big countdown ring, WORK / REST, live heart rate
  and calories, and the current combo in large type: `1-2-3`,
  `JAB-CROSS-HOOK`, `1-3B-2-PIVOT`. Swipe right for Pause / End, as in Apple's
  Workout app. There's no close button, so a sweaty palm can't end a round.

## Haptics are the feature

| Moment | What the wrist feels (`WKHapticType`) |
|---|---|
| Last 3 s of the get-ready, and of every rest | `.click` × 3 (one per second), then… |
| Round start | `.start` |
| A combo is called | one `.click` per move (defense and the pivot included, since they're beats of the combo), 0.14 s apart, then `.directionUp` ("go") |
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
  Moves.swift              The moves library: punches 1–6, body 1B–4B, slip/roll/duck/pull/parry, pivot,
                           and Muay Thai's teep, kicks, knee, elbow
  ComboGenerator.swift     Seeded combo builder (discipline, intensity, defense, body shots), or your own combos
  SeededRandom.swift       SplitMix64, so a seed means the same combos on every platform
  Workout.swift            Workout settings, the defaults, duration math and formatting
  Cue.swift                Cues → haptic patterns (Pulse + timing), as data
  WorkoutPlan.swift        The whole workout written out: segments + every cue, timestamped
  WorkoutEngine.swift      A state machine that walks the plan against an injected clock
App/                       SwiftUI watch app: screens, the combo builder, a 10 Hz driver, HealthKit,
                           Pulse → WKHapticType
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

- Punches alternate hands. The one exception is the double jab: 1-1, or 1-1B.
- Body shots are only 1B–4B, only in boxing, and only when switched on.
- Evasions (slip, roll, duck, pull, parry) are never first, never last, and
  never twice in a row.
- A pivot only ever ends a combo, and never straight after an evasion.
- In Muay Thai (core only), a combo always lands a kick, knee, elbow or teep. A
  kick goes off the side opposite the last punch: 1-2 → LEFT KICK,
  1 → RIGHT KICK.
- Your own combos are drawn at random but never twice in a row. With none
  saved, a "My combos" workout generates instead of going silent.

Boxing's numbers are stance-relative (1 is always the jab, whichever hand
leads), so a southpaw needs no setting. The numbers and the taps are the same.

**Tests.** `swift test` runs 47 tests covering:

- the moves, body shots and callouts;
- the duration math and formatting;
- the defaults, and loading a workout saved by an older build;
- combo generation: determinism, pinned sequences, the rules above, library
  coverage, and My Combos;
- the exact timelines and the cue patterns;
- the engine: full walk, catch-up, pause, end early and status.

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
