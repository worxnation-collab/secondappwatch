import Foundation

/// One tap on the wrist. The watch maps these 1:1 onto WKHapticType; keeping
/// them here makes every pattern data the tests can read.
public enum Pulse: String, Sendable, Equatable, CaseIterable {
    case start, click, directionUp, notification, stop, success
}

public struct Beat: Sendable, Equatable {
    public let pulse: Pulse
    /// Seconds after the cue fires.
    public let at: TimeInterval
    public init(_ pulse: Pulse, at: TimeInterval) { self.pulse = pulse; self.at = at }
}

/// Something the workout wants the wrist to feel.
public enum Cue: Sendable, Equatable {
    /// The last three seconds of the get-ready and of every rest.
    case getSet(secondsLeft: Int)
    case roundStart(round: Int)
    case combo(Combo)
    case tenSeconds
    /// One strike of the countdown drill, counting down to 1.
    case count(Int, CountdownDrill)
    /// End of a round.
    case bell(round: Int)
    case done

    /// Gap between the taps of a combo: quick enough to read as one phrase,
    /// slow enough that four taps don't smear into a buzz.
    public static let tapGap: TimeInterval = 0.14

    public var pattern: [Beat] {
        switch self {
        case .getSet: return [Beat(.click, at: 0)]
        case .roundStart: return [Beat(.start, at: 0)]
        case .combo(let combo):
            // One tap per move, then a rising cue that means "go".
            var beats = combo.moves.indices.map { Beat(.click, at: Double($0) * Cue.tapGap) }
            beats.append(Beat(.directionUp, at: Double(combo.moves.count) * Cue.tapGap + 0.06))
            return beats
        case .tenSeconds: return [Beat(.notification, at: 0)]
        case .count: return [Beat(.click, at: 0)]
        case .bell: return [Beat(.stop, at: 0)]
        case .done: return [Beat(.success, at: 0.6)]
        }
    }

    /// Structural cues change what phase you're in. After the app has been
    /// asleep they still play when it catches up; a stale combo or tick does
    /// not, because a tap for something that's already over means nothing.
    public var isStructural: Bool {
        switch self {
        case .roundStart, .bell, .done: return true
        case .getSet, .combo, .tenSeconds, .count: return false
        }
    }
}
