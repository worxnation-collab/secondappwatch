import XCTest
@testable import RoundCore

final class MovesTests: XCTestCase {
    func testNumbersAndHands() {
        XCTAssertEqual((1...6).map { Move.punch($0).number }, [1, 2, 3, 4, 5, 6])
        XCTAssertEqual((1...6).map { Move.punch($0).hand }, [.lead, .rear, .lead, .rear, .lead, .rear])
        XCTAssertNil(Move.slip.number)
        XCTAssertNil(Move.teep.hand)
        XCTAssertNil(Move.pivot.hand)
    }

    func testBodyShots() {
        XCTAssertEqual((1...6).map { Move.punch($0).bodyVersion?.code }, ["1B", "2B", "3B", "4B", nil, nil])
        for m in Move.allCases where m.isBody {
            XCTAssertEqual(m.headVersion.bodyVersion, m)
            XCTAssertEqual(m.hand, m.headVersion.hand)
            XCTAssertEqual(m.kind, .punch)
        }
    }

    func testCallouts() {
        XCTAssertEqual(Combo([.jab, .cross, .leadHook]).callout(.numbers), "1-2-3")
        XCTAssertEqual(Combo([.jab, .cross, .leadHook]).callout(.names), "JAB-CROSS-HOOK")
        XCTAssertEqual(Combo([.jab, .cross, .slip, .cross]).callout(.numbers), "1-2-SLIP-2")
        XCTAssertEqual(Combo([.jab, .bodyHook, .cross, .pivot]).callout(.numbers), "1-3B-2-PIVOT")
        XCTAssertEqual(Combo([.bodyJab, .cross]).callout(.names), "BODY JAB-CROSS")
        XCTAssertEqual(Combo([.teep]).callout(.numbers), "TEEP")
        XCTAssertEqual(Combo([.rightKick]).callout(.names), "RIGHT KICK")
    }

    func testLibraries() {
        XCTAssertEqual(Set(Move.library(for: .boxing)), [
            .jab, .cross, .leadHook, .rearHook, .leadUppercut, .rearUppercut,
            .bodyJab, .bodyCross, .bodyHook, .bodyRearHook,
            .slip, .roll, .duck, .pull, .parry, .pivot,
        ])
        let thai = Set(Move.library(for: .muayThai))
        XCTAssertTrue(thai.isSuperset(of: [.teep, .leftKick, .rightKick, .knee, .elbow, .jab, .cross]))
        XCTAssertFalse(thai.contains(.slip))
        XCTAssertFalse(thai.contains(.bodyJab))
    }

    func testCombosRoundTripAndRejectEmpty() throws {
        let c = Combo([.jab, .bodyHook, .pivot])
        XCTAssertEqual(try JSONDecoder().decode(Combo.self, from: JSONEncoder().encode(c)), c)
        XCTAssertThrowsError(try JSONDecoder().decode(Combo.self, from: Data(#"{"moves":[]}"#.utf8)))
    }
}

final class DurationTests: XCTestCase {
    private func workout(rounds: Int, work: Int, rest: Int) -> Workout {
        Workout(id: "t", name: "t", discipline: .boxing, rounds: rounds, work: work, rest: rest, intensity: .low)
    }

    func testTotalHasNoRestAfterTheLastRound() {
        XCTAssertEqual(workout(rounds: 2, work: 120, rest: 30).totalSeconds, 270)  // 4:30
        XCTAssertEqual(workout(rounds: 3, work: 120, rest: 30).totalSeconds, 420)
        XCTAssertEqual(workout(rounds: 1, work: 90, rest: 60).totalSeconds, 90)
        XCTAssertEqual(workout(rounds: 4, work: 180, rest: 0).totalSeconds, 720)
    }

    func testDefaultsShowTheRightTotals() {
        let totals = Workout.defaults.map { DurationFormat.clock($0.totalSeconds) }
        XCTAssertEqual(totals, ["4:30", "7:00", "11:00"])
    }

    func testClockAlwaysShowsSeconds() {
        XCTAssertEqual(DurationFormat.clock(270), "4:30")
        XCTAssertEqual(DurationFormat.clock(30), "0:30")   // never "0m"
        XCTAssertEqual(DurationFormat.clock(300), "5:00")  // never "5m"
        XCTAssertEqual(DurationFormat.clock(59), "0:59")
        XCTAssertEqual(DurationFormat.clock(0), "0:00")
        XCTAssertEqual(DurationFormat.clock(3750), "1:02:30")
        XCTAssertEqual(DurationFormat.clock(-5), "0:00")
    }

    func testCountdownRoundsUp() {
        XCTAssertEqual(DurationFormat.countdown(0.2), "0:01")
        XCTAssertEqual(DurationFormat.countdown(119.5), "2:00")
        XCTAssertEqual(DurationFormat.countdown(0), "0:00")
    }

    func testClampHoldsStoredValuesToThePickers() {
        let w = workout(rounds: 0, work: 5, rest: 999).clamped()
        XCTAssertEqual([w.rounds, w.work, w.rest], [1, 30, 120])
    }
}

final class DefaultsTests: XCTestCase {
    func testDefaultsMatchThePhoneApp() {
        let byName = Dictionary(uniqueKeysWithValues: Workout.defaults.map { ($0.name, $0) })
        let speed = try! XCTUnwrap(byName["Speed Demon"])
        XCTAssertEqual(speed.discipline, .boxing)
        XCTAssertEqual([speed.rounds, speed.work, speed.rest], [2, 120, 30])
        XCTAssertEqual(speed.intensity, .high)

        let flow = try! XCTUnwrap(byName["Creative Flow"])
        XCTAssertEqual(flow.discipline, .boxing)
        XCTAssertEqual([flow.rounds, flow.work, flow.rest], [3, 120, 30])
        XCTAssertEqual(flow.intensity, .medium)
        XCTAssertEqual(flow.callout, .numbers)
        XCTAssertTrue(flow.defense)
        XCTAssertTrue(flow.bodyShots)

        XCTAssertEqual(Workout.defaults.filter { $0.discipline == .muayThai }.count, 1)
        XCTAssertEqual(Set(Workout.defaults.map(\.id)).count, Workout.defaults.count)
    }

    func testCountdownDrills() {
        var w = Workout.defaults[2]  // Muay Thai, both drills on
        XCTAssertEqual((1...4).map { w.countdownDrill(round: $0) }, [.punches, .kicks, .punches, .kicks])
        w.punchCountdown = false
        XCTAssertEqual(w.countdownDrill(round: 1), .kicks)
        w.work = 15
        XCTAssertNil(w.countdownDrill(round: 1), "no room for combos before the drill")

        var boxing = Workout.defaults[0]
        boxing.punchCountdown = false
        boxing.kickCountdown = true
        XCTAssertNil(boxing.countdownDrill(round: 1), "boxing has no kicks to count")
    }

    func testAWorkoutSavedByAnOlderBuildStillLoads() throws {
        // What 0.1 wrote: no bodyShots, no comboSource.
        let old = #"{"id":"speed-demon","name":"Speed Demon","discipline":"boxing","rounds":4,"work":90,"rest":45,"intensity":"low","callout":"names","defense":false,"punchCountdown":true,"kickCountdown":false}"#
        let w = try JSONDecoder().decode(Workout.self, from: Data(old.utf8))
        XCTAssertEqual([w.rounds, w.work, w.rest], [4, 90, 45], "the edits survive")
        XCTAssertFalse(w.bodyShots)
        XCTAssertEqual(w.comboSource, .generated)
    }

    func testWorkoutsRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(Workout.defaults)
        XCTAssertEqual(try JSONDecoder().decode([Workout].self, from: data), Workout.defaults)
    }
}
