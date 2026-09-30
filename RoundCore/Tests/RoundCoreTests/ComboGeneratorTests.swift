import XCTest
@testable import RoundCore

final class ComboGeneratorTests: XCTestCase {
    private func combos(_ d: Discipline, _ i: Intensity, defense: Bool = false, body: Bool = false,
                        seed: UInt64 = 42, count: Int = 400) -> [Combo] {
        var g = ComboGenerator(discipline: d, intensity: i, defense: defense, bodyShots: body, seed: seed)
        return (0..<count).map { _ in g.next() }
    }

    func testSameSeedSameCombos() {
        XCTAssertEqual(combos(.boxing, .high, seed: 7, count: 50), combos(.boxing, .high, seed: 7, count: 50))
        XCTAssertNotEqual(combos(.boxing, .high, seed: 7, count: 50), combos(.boxing, .high, seed: 8, count: 50))
    }

    func testPinnedSequences() {
        // Guards the generator against accidental change: the workout seed 1
        // calls today is the workout it calls on the next build.
        XCTAssertEqual(combos(.boxing, .medium, seed: 1, count: 4).map { $0.callout(.numbers) },
                       ["1-2-3", "1-2", "1-6", "1-4"])
        XCTAssertEqual(combos(.muayThai, .high, seed: 1, count: 4).map { $0.callout(.names) },
                       ["JAB-CROSS-HOOK-RIGHT KICK", "JAB-RIGHT KICK", "JAB-REAR UPPER-LEFT KICK", "JAB-CROSS-LEFT KICK"])
    }

    func testLengthFollowsIntensity() {
        for d in Discipline.allCases {
            for i in Intensity.allCases {
                let lengths = Set(combos(d, i).map(\.moves.count))
                XCTAssertEqual(lengths, Set(i.comboLength), "\(d) \(i)")
            }
        }
    }

    func testMovesComeFromTheDisciplinesLibrary() {
        for d in Discipline.allCases {
            let lib = Set(Move.library(for: d))
            for c in combos(d, .high, defense: true, body: true) {
                XCTAssertTrue(Set(c.moves).isSubset(of: lib), c.callout(.names))
            }
        }
    }

    func testTheWholeLibraryGetsUsed() {
        let boxing = Set(combos(.boxing, .high, defense: true, body: true, count: 1000).flatMap(\.moves))
        XCTAssertEqual(boxing, Set(Move.library(for: .boxing)))
        let thai = Set(combos(.muayThai, .low, count: 500).flatMap(\.moves)
                       + combos(.muayThai, .high, count: 500).flatMap(\.moves))
        XCTAssertEqual(thai, Set(Move.library(for: .muayThai)))
    }

    func testPunchesAlternateHandsExceptTheDoubleJab() {
        var sawDoubleJab = false
        for c in combos(.boxing, .high, defense: true, body: true, count: 1000) {
            for (a, b) in zip(c.moves, c.moves.dropFirst()) {
                guard let ha = a.hand, let hb = b.hand else { continue }
                if a.headVersion == .jab && b.headVersion == .jab { sawDoubleJab = true; continue }
                XCTAssertNotEqual(ha, hb, c.callout(.numbers))
            }
        }
        XCTAssertTrue(sawDoubleJab)
    }

    func testEvasionsLiveInsideACombo() {
        var saw = Set<Move>()
        for c in combos(.boxing, .high, defense: true, body: true, count: 2000) {
            XCTAssertEqual(c.moves.first?.kind, .punch, c.callout(.numbers))
            XCTAssertNotEqual(c.moves.last?.kind, .defense, c.callout(.numbers))
            for (a, b) in zip(c.moves, c.moves.dropFirst()) where a.kind == .defense {
                saw.insert(a)
                XCTAssertNotEqual(b.kind, .defense, c.callout(.numbers))
                XCTAssertNotEqual(b, .pivot, "dodging straight into walking away: \(c.callout(.numbers))")
            }
        }
        XCTAssertEqual(saw, [.slip, .roll, .duck, .pull, .parry])
    }

    func testPivotOnlyEndsACombo() {
        var sawPivot = false
        for c in combos(.boxing, .high, defense: true, count: 2000) {
            for (i, m) in c.moves.enumerated() where m == .pivot {
                sawPivot = true
                XCTAssertEqual(i, c.moves.count - 1, c.callout(.numbers))
            }
        }
        XCTAssertTrue(sawPivot)
    }

    func testBodyShotsAreOneToFourAndOnlyWhenOn() {
        let on = combos(.boxing, .high, body: true, count: 1000).flatMap(\.moves)
        XCTAssertEqual(Set(on.filter(\.isBody)), [.bodyJab, .bodyCross, .bodyHook, .bodyRearHook])
        XCTAssertFalse(combos(.boxing, .high, body: false).flatMap(\.moves).contains { $0.isBody })
        XCTAssertFalse(combos(.muayThai, .high, body: true).flatMap(\.moves).contains { $0.isBody },
                       "body shots are a boxing option")
    }

    func testNoDefenseWhenItsOff() {
        XCTAssertFalse(combos(.boxing, .high, defense: false).flatMap(\.moves).contains { $0.kind == .defense })
    }

    func testMuayThaiLandsALimbAndKicksOffTheOppositeSide() {
        for i in Intensity.allCases {
            for c in combos(.muayThai, i) {
                XCTAssertTrue(c.moves.contains { $0.kind != .punch }, c.callout(.names))
                guard c.moves.count >= 2, let last = c.moves.last, last.kind == .kick else { continue }
                let hand = c.moves[c.moves.count - 2].hand
                XCTAssertEqual(last, hand == .rear ? .leftKick : .rightKick, c.callout(.names))
            }
        }
    }

    func testMuayThaiDefaultHasKicksAndKnees() {
        let thai = Workout.defaults.first { $0.discipline == .muayThai }!
        var g = ComboGenerator(workout: thai, seed: 3)
        let kinds = Set((0..<100).flatMap { _ in g.next().moves.map(\.kind) })
        XCTAssertTrue(kinds.contains(.kick))
        XCTAssertTrue(kinds.contains(.knee))
    }

    func testMyCombosAreDrawnWithoutImmediateRepeats() {
        let mine = [Combo([.jab, .cross]), Combo([.jab, .jab, .cross]), Combo([.leadHook, .cross, .pivot])]
        var g = ComboGenerator(discipline: .boxing, intensity: .high, mine: mine, seed: 5)
        let drawn = (0..<300).map { _ in g.next() }
        XCTAssertEqual(Set(drawn), Set(mine), "only yours, and all of yours")
        for (a, b) in zip(drawn, drawn.dropFirst()) { XCTAssertNotEqual(a, b) }

        var one = ComboGenerator(discipline: .boxing, intensity: .high, mine: [mine[0]], seed: 5)
        XCTAssertEqual((0..<5).map { _ in one.next() }, Array(repeating: mine[0], count: 5))
    }

    func testMyCombosOnlyWhenTheWorkoutAsks() {
        var w = Workout.defaults[0]
        let mine = [Combo([.rearUppercut])]
        w.comboSource = .generated
        var gen = ComboGenerator(workout: w, mine: mine, seed: 1)
        XCTAssertTrue((0..<50).contains { _ in gen.next() != mine[0] })

        w.comboSource = .mine
        var yours = ComboGenerator(workout: w, mine: mine, seed: 1)
        XCTAssertEqual(yours.next(), mine[0])

        var none = ComboGenerator(workout: w, mine: [], seed: 1)
        XCTAssertTrue((1...4).contains(none.next().moves.count), "no combos built yet: generate instead")
    }

    func testRandomIsUnbiasedEnough() {
        var r = SeededRandom(seed: 9)
        var counts = [0, 0, 0]
        for _ in 0..<3000 { counts[r.int(below: 3)] += 1 }
        for c in counts { XCTAssert((900...1100).contains(c), "\(counts)") }
    }
}
