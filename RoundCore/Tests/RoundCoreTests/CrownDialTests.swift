import XCTest
@testable import RoundCore

final class CrownDialTests: XCTestCase {
    private func feed(_ values: [Double], into dial: inout CrownDial) -> [CrownDial.Event] {
        values.compactMap { dial.update($0) }
    }

    func testTurnToTheEndCommits() {
        var d = CrownDial()
        XCTAssertEqual(feed([0.1, 0.3, 0.5, 0.7, 0.9, 0.99], into: &d), [.armed(true), .committed(true)])
        XCTAssertTrue(d.committed)
    }

    func testFalseIsTheOtherWay() {
        var d = CrownDial()
        XCTAssertEqual(feed([-0.2, -0.6, -1], into: &d), [.armed(false), .committed(false)])
    }

    func testNudgeWhileReadingDoesNothing() {
        var d = CrownDial()
        XCTAssertEqual(feed([0.2, 0.45, 0.1, -0.3, -0.45, 0], into: &d), [])
    }

    func testBackingOffDisarmsWithHysteresis() {
        var d = CrownDial()
        // 0.4 is between disarm and arm: stays armed, no chatter.
        XCTAssertEqual(feed([0.6, 0.4, 0.55, 0.4, 0.3], into: &d), [.armed(true), .disarmed])
        XCTAssertNil(d.armed)
        XCTAssertFalse(d.committed)
    }

    func testWhipAcrossRearmsOtherSide() {
        var d = CrownDial()
        XCTAssertEqual(feed([0.7, -0.7, -1], into: &d), [.armed(true), .armed(false), .committed(false)])
    }

    func testJumpStraightToEndArmsBeforeCommitting() {
        // A fast spin can land at the end stop in one reading; the wrist
        // should still feel the arm click before the answer goes.
        var d = CrownDial()
        XCTAssertEqual(feed([1, 1], into: &d), [.armed(true), .committed(true)])
    }

    func testNothingAfterCommitUntilReset() {
        var d = CrownDial()
        _ = feed([0.6, 1], into: &d)
        XCTAssertEqual(feed([-1, 0, 1], into: &d), [])
        d.reset()
        XCTAssertEqual(feed([-0.6], into: &d), [.armed(false)])
    }
}
