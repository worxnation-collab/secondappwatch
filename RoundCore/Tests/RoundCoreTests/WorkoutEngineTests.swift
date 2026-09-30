import XCTest
@testable import RoundCore

/// A cue written the way the tests read it: "7 combo", "25 ten", "35 bell1".
private func describe(_ t: TimedCue) -> String {
    let time = t.at == t.at.rounded() ? String(Int(t.at)) : String(t.at)
    return time + " " + describe(t.cue)
}

private func describe(_ cue: Cue) -> String {
    switch cue {
    case .getSet(let n): return "set\(n)"
    case .roundStart(let r): return "start\(r)"
    case .combo: return "combo"
    case .tenSeconds: return "ten"
    case .count(let n, let d): return "\(d == .punches ? "p" : "k")\(n)"
    case .bell(let r): return "bell\(r)"
    case .done: return "done"
    }
}

private func workout(rounds: Int = 2, work: Int = 30, rest: Int = 15, intensity: Intensity = .high,
                     discipline: Discipline = .boxing, punch: Bool = false, kick: Bool = false) -> Workout {
    Workout(id: "t", name: "t", discipline: discipline, rounds: rounds, work: work, rest: rest,
            intensity: intensity, punchCountdown: punch, kickCountdown: kick)
}

final class WorkoutPlanTests: XCTestCase {
    func testExactTimeline() {
        // 5s get-ready, then 2 x 0:30 with 0:15 rest, High = a combo every 3s.
        let plan = WorkoutPlan(workout: workout(), seed: 1)
        XCTAssertEqual(plan.cues.map(describe), [
            "2 set3", "3 set2", "4 set1",
            "5 start1",
            "7 combo", "10 combo", "13 combo", "16 combo", "19 combo", "22 combo",
            // 25 would land on the 10-second tap, so it's skipped.
            "25 ten",
            "28 combo", "31 combo",
            // 34 is inside the last 2.5s: nothing starts at the bell.
            "35 bell1",
            "47 set3", "48 set2", "49 set1",
            "50 start2",
            "52 combo", "55 combo", "58 combo", "61 combo", "64 combo", "67 combo",
            "70 ten",
            "73 combo", "76 combo",
            "80 bell2", "80 done",
        ])
        XCTAssertEqual(plan.duration, 80)
        XCTAssertEqual(plan.segments.map(\.kind), [.getReady, .work(round: 1), .rest(nextRound: 2), .work(round: 2)])
    }

    func testPunchCountdownTakesTheLastTenSeconds() {
        let plan = WorkoutPlan(workout: workout(rounds: 1, punch: true), seed: 1)
        XCTAssertEqual(plan.cues.map(describe), [
            "2 set3", "3 set2", "4 set1",
            "5 start1",
            "7 combo", "10 combo", "13 combo", "16 combo", "19 combo", "22 combo",
            "25 ten",
            "26 p9", "27 p8", "28 p7", "29 p6", "30 p5", "31 p4", "32 p3", "33 p2", "34 p1",
            "35 bell1", "35 done",
        ])
    }

    func testMuayThaiAlternatesPunchAndKickCountdowns() {
        let plan = WorkoutPlan(workout: workout(rounds: 2, rest: 0, discipline: .muayThai, punch: true, kick: true), seed: 1)
        let drills = plan.cues.compactMap { t -> String? in
            if case .count(9, let d) = t.cue { return d.rawValue } else { return nil }
        }
        XCTAssertEqual(drills, ["punches", "kicks"])
    }

    func testNoRestMeansNoGetSetBetweenRounds() {
        let plan = WorkoutPlan(workout: workout(rest: 0), seed: 1)
        let between = plan.cues.filter { $0.at > 5 && $0.at < 36 }.map(describe)
        XCTAssertFalse(between.contains { $0.hasSuffix("set1") })
        XCTAssertTrue(between.contains("35 start2"))
        XCTAssertEqual(plan.duration, 65)
    }

    func testCombosFollowIntensityInterval() {
        for i in Intensity.allCases {
            let times = WorkoutPlan(workout: workout(rounds: 1, work: 120, intensity: i), seed: 2).cues
                .filter { if case .combo = $0.cue { return true } else { return false } }
                .map(\.at)
            for (a, b) in zip(times, times.dropFirst()) {
                let gap = b - a
                XCTAssert(abs(gap - i.callInterval) < 1e-9 || abs(gap - 2 * i.callInterval) < 1e-9, "\(i) \(gap)")
            }
        }
    }

    func testAPlanCanCallOnlyYourCombos() {
        var w = workout()
        w.comboSource = .mine
        let mine = [Combo([.jab, .cross]), Combo([.leadHook, .bodyCross])]
        let called = WorkoutPlan(workout: w, seed: 3, mine: mine).cues.compactMap { t -> Combo? in
            if case .combo(let c) = t.cue { return c } else { return nil }
        }
        XCTAssertEqual(called.count, 16)
        XCTAssertEqual(Set(called), Set(mine))
    }

    func testTotalMatchesTheHomeScreen() {
        for w in Workout.defaults {
            XCTAssertEqual(WorkoutPlan(workout: w, seed: 0).duration, WorkoutPlan.getReady + Double(w.totalSeconds))
        }
    }
}

final class CueTests: XCTestCase {
    func testComboIsOneTapPerMoveThenGo() {
        XCTAssertEqual(Cue.combo(Combo([.jab, .cross])).pattern, [
            Beat(.click, at: 0), Beat(.click, at: 0.14), Beat(.directionUp, at: 0.34),
        ])
        XCTAssertEqual(Cue.combo(Combo([.teep])).pattern, [Beat(.click, at: 0), Beat(.directionUp, at: 0.2)])
        let four = Cue.combo(Combo([.jab, .cross, .slip, .cross])).pattern
        XCTAssertEqual(four.map(\.pulse), [.click, .click, .click, .click, .directionUp])
    }

    func testFixedCues() {
        XCTAssertEqual(Cue.roundStart(round: 1).pattern, [Beat(.start, at: 0)])
        XCTAssertEqual(Cue.tenSeconds.pattern, [Beat(.notification, at: 0)])
        XCTAssertEqual(Cue.bell(round: 1).pattern, [Beat(.stop, at: 0)])
        XCTAssertEqual(Cue.count(3, .kicks).pattern, [Beat(.click, at: 0)])
    }

    func testRestEndsWithThreeClicksThenStart() {
        let plan = WorkoutPlan(workout: workout(), seed: 1)
        let pulses = plan.cues.filter { $0.at >= 35 && $0.at <= 50 }.flatMap { $0.cue.pattern.map(\.pulse) }
        XCTAssertEqual(pulses, [.stop, .click, .click, .click, .start])
    }

    func testGetReadyEndsTheSameWay() {
        let plan = WorkoutPlan(workout: workout(), seed: 1)
        let pulses = plan.cues.filter { $0.at <= 5 }.flatMap { $0.cue.pattern.map(\.pulse) }
        XCTAssertEqual(pulses, [.click, .click, .click, .start])
    }

    func testTapsInAComboNeverOverlapTheNextCall() {
        // The longest combo's taps finish well before High's 3s interval.
        let longest = Cue.combo(Combo([.jab, .cross, .leadHook, .cross])).pattern.last!.at
        XCTAssertLessThan(longest, Intensity.high.callInterval / 3)
    }
}

final class WorkoutEngineTests: XCTestCase {
    private let t0: TimeInterval = 1000

    func testTickingWalksThePlanExactly() {
        var e = WorkoutEngine(workout: workout(), seed: 1)
        var got: [String] = []
        got += e.start(at: t0).map(describe)
        var t = 0.0
        while e.state == .running {
            t += 0.1
            got += e.tick(at: t0 + t).map(describe)
        }
        XCTAssertEqual(got, e.plan.cues.map { describe($0.cue) })
        XCTAssertEqual(e.state, .finished)
        XCTAssertEqual(e.tick(at: t0 + 200), [])
    }

    func testCatchingUpKeepsStructureAndDropsStaleTaps() {
        var e = WorkoutEngine(workout: workout(), seed: 1)
        _ = e.start(at: t0)
        // Asleep from 0 to 40.5: only the round start and bell survive, and
        // nothing called more than a second ago.
        XCTAssertEqual(e.tick(at: t0 + 40.5).map(describe), ["start1", "bell1"])
        XCTAssertEqual(e.tick(at: t0 + 47.2).map(describe), ["set3"])
    }

    func testPauseFreezesTheClock() {
        var e = WorkoutEngine(workout: workout(), seed: 1)
        _ = e.start(at: t0)
        _ = e.tick(at: t0 + 8)
        _ = e.pause(at: t0 + 8)
        XCTAssertEqual(e.state, .paused)
        XCTAssertEqual(e.tick(at: t0 + 500), [])
        let paused = e.status(at: t0 + 500)
        XCTAssertTrue(paused.isPaused)
        XCTAssertEqual(paused.remaining, 27, accuracy: 1e-9)
        XCTAssertEqual(e.resume(at: t0 + 500), [])
        // Two seconds after resuming is plan time 10: the 10s combo.
        XCTAssertEqual(e.tick(at: t0 + 502).map(describe), ["combo"])
    }

    func testEndingEarlyIsDoneAndQuiet() {
        var e = WorkoutEngine(workout: workout(), seed: 1)
        _ = e.start(at: t0)
        _ = e.tick(at: t0 + 20)
        XCTAssertEqual(e.end(at: t0 + 20), [.done])
        XCTAssertEqual(e.state, .finished)
        XCTAssertEqual(e.tick(at: t0 + 30), [])
        XCTAssertEqual(e.end(at: t0 + 30), [])
        let s = e.status(at: t0 + 90)
        XCTAssertEqual(s.phase, .done)
        XCTAssertEqual(s.activeSeconds, 15, accuracy: 1e-9)
    }

    func testCallsOutOfOrderAreIgnored() {
        var e = WorkoutEngine(workout: workout(), seed: 1)
        XCTAssertEqual(e.tick(at: t0), [])
        XCTAssertEqual(e.pause(at: t0), [])
        XCTAssertEqual(e.resume(at: t0), [])
        XCTAssertEqual(e.end(at: t0), [])
        _ = e.start(at: t0)
        XCTAssertEqual(e.start(at: t0 + 1), [])
    }

    func testStatusThroughTheWorkout() {
        var e = WorkoutEngine(workout: workout(rounds: 2, punch: true), seed: 1)
        _ = e.start(at: t0)

        let ready = e.status(at: t0 + 1)
        XCTAssertEqual(ready.phase, .getReady)
        XCTAssertEqual(ready.remaining, 4, accuracy: 1e-9)

        let early = e.status(at: t0 + 6)
        XCTAssertEqual(early.phase, .work(round: 1))
        XCTAssertNil(early.combo, "nothing called yet")
        XCTAssertEqual(early.fraction, 29.0 / 30.0, accuracy: 1e-9)

        let first = e.plan.cues.first { if case .combo = $0.cue { return true } else { return false } }!
        guard case .combo(let firstCombo) = first.cue else { return XCTFail() }
        XCTAssertEqual(e.status(at: t0 + 7.5).combo, firstCombo)

        let drill = e.status(at: t0 + 27.5)  // 7.5s left
        XCTAssertEqual(drill.drill, Status.DrillCount(drill: .punches, count: 8))
        XCTAssertNil(drill.combo, "the count replaces the combo")
        XCTAssertEqual(e.status(at: t0 + 25.5).drill?.count, 10)

        let rest = e.status(at: t0 + 40)
        XCTAssertEqual(rest.phase, .rest(nextRound: 2))
        XCTAssertEqual(rest.remaining, 10, accuracy: 1e-9)
        XCTAssertNil(rest.combo)

        XCTAssertEqual(e.status(at: t0 + 51).combo, nil, "a new round starts clean")
        XCTAssertEqual(e.status(at: t0 + 80).phase, .done)
        XCTAssertEqual(e.status(at: t0 + 80).activeSeconds, 75, accuracy: 1e-9)
    }
}
