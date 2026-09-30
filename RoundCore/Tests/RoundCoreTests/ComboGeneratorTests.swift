import XCTest
@testable import RoundCore

final class ComboGeneratorTests: XCTestCase {
    private func combos(_ d: Discipline, _ i: Intensity, defense: Bool = false, seed: UInt64 = 42, count: Int = 400) -> [Combo] {
        var g = ComboGenerator(discipline: d, intensity: i, defense: defense, seed: seed)
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
            for c in combos(d, .high, defense: true) {
                XCTAssertTrue(Set(c.moves).isSubset(of: lib), c.callout(.names))
            }
        }
    }

    func testTheWholeLibraryGetsUsed() {
        let boxing = Set(combos(.boxing, .high, defense: true, count: 1000).flatMap(\.moves))
        XCTAssertEqual(boxing, Set(Move.library(for: .boxing)))
        let thai = Set(combos(.muayThai, .low, count: 500).flatMap(\.moves)
                       + combos(.muayThai, .high, count: 500).flatMap(\.moves))
        XCTAssertEqual(thai, Set(Move.library(for: .muayThai)))
    }

    func testPunchesAlternateHandsExceptTheDoubleJab() {
        var sawDoubleJab = false
        for c in combos(.boxing, .high, defense: true, count: 1000) {
            for (a, b) in zip(c.moves, c.moves.dropFirst()) {
                guard let ha = a.hand, let hb = b.hand else { continue }
                if a == .jab && b == .jab { sawDoubleJab = true; continue }
                XCTAssertNotEqual(ha, hb, c.callout(.numbers))
            }
        }
        XCTAssertTrue(sawDoubleJab)
    }

    func testDefenseIsNeverFirstLastOrDoubled() {
        var sawDefense = false
        for c in combos(.boxing, .high, defense: true, count: 1000) {
            XCTAssertEqual(c.moves.first?.kind, .punch)
            XCTAssertEqual(c.moves.last?.kind, .punch)
            for (a, b) in zip(c.moves, c.moves.dropFirst()) where a.kind == .defense {
                sawDefense = true
                XCTAssertNotEqual(b.kind, .defense)
            }
        }
        XCTAssertTrue(sawDefense)
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

    func testRandomIsUnbiasedEnough() {
        var r = SeededRandom(seed: 9)
        var counts = [0, 0, 0]
        for _ in 0..<3000 { counts[r.int(below: 3)] += 1 }
        for c in counts { XCTAssert((900...1100).contains(c), "\(counts)") }
    }
}
