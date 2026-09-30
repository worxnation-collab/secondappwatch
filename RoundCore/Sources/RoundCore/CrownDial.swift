import Foundation

/// Answering with the Digital Crown, as a pure state machine.
///
/// The crown travels from -1 (False) to +1 (True), resting at 0. Turn past
/// halfway and the side ARMS: a click on the wrist and the label lights. Keep
/// turning to the end stop and it COMMITS. Ease back toward the middle before
/// the end and it disarms, so a nudge while reading never answers anything.
/// That makes it answerable eyes-free: click means "you're on True", the end
/// stop means "sent".
public struct CrownDial: Sendable, Equatable {
    public enum Event: Sendable, Equatable {
        case armed(Bool)
        case disarmed
        case committed(Bool)
    }

    public static let armAt = 0.5
    /// Lower than `armAt` so a thumb resting on the threshold doesn't chatter.
    public static let disarmBelow = 0.35
    /// Just short of the end stop: a non-continuous crown settles at ~0.99.
    public static let commitAt = 0.95

    public private(set) var armed: Bool?
    public private(set) var committed = false
    /// 0...1 progress toward committing the armed side, for the UI.
    public private(set) var travel = 0.0

    public init() {}

    /// Feed every crown value. Returns at most one event per call.
    public mutating func update(_ value: Double) -> Event? {
        guard !committed else { return nil }
        let v = max(-1, min(1, value))
        let side = v >= 0
        let reach = abs(v)
        travel = reach

        if let current = armed {
            if current != side || reach < CrownDial.disarmBelow {
                armed = nil
                // Whipped straight across to the other side in one reading.
                if reach >= CrownDial.armAt { armed = side; return .armed(side) }
                return .disarmed
            }
            if reach >= CrownDial.commitAt {
                committed = true
                return .committed(current)
            }
            return nil
        }
        guard reach >= CrownDial.armAt else { return nil }
        armed = side
        return .armed(side)
    }

    /// A new question: back to the middle, nothing armed.
    public mutating func reset() { self = CrownDial() }
}
