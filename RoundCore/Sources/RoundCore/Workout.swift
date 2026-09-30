import Foundation

/// Intensity is combo FREQUENCY and LENGTH, nothing else.
public enum Intensity: String, Codable, Sendable, CaseIterable {
    case low, medium, high

    public var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Seconds between one combo call and the next.
    public var callInterval: TimeInterval {
        switch self {
        case .low: return 6
        case .medium: return 4.5
        case .high: return 3
        }
    }

    /// Moves per combo.
    public var comboLength: ClosedRange<Int> {
        switch self {
        case .low: return 1...2
        case .medium: return 2...3
        case .high: return 2...4
        }
    }
}

public struct Workout: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var discipline: Discipline
    public var rounds: Int
    /// Seconds of work per round.
    public var work: Int
    /// Seconds of rest between rounds. There is no rest after the last round.
    public var rest: Int
    public var intensity: Intensity
    public var callout: CalloutStyle
    /// Mix slips and rolls into boxing combos.
    public var defense: Bool
    /// The last ten seconds of a round become a count: one punch per second.
    public var punchCountdown: Bool
    /// Same, with kicks. Muay Thai only.
    public var kickCountdown: Bool

    public init(id: String, name: String, discipline: Discipline, rounds: Int, work: Int, rest: Int,
                intensity: Intensity, callout: CalloutStyle = .names, defense: Bool = false,
                punchCountdown: Bool = false, kickCountdown: Bool = false) {
        self.id = id; self.name = name; self.discipline = discipline
        self.rounds = rounds; self.work = work; self.rest = rest
        self.intensity = intensity; self.callout = callout; self.defense = defense
        self.punchCountdown = punchCountdown; self.kickCountdown = kickCountdown
    }

    // The ranges the watch's pickers offer. `clamped()` holds any stored
    // workout to them, so a bad value on disk can't build a 0-round workout.
    public static let roundsRange = 1...12
    public static let workOptions = Array(stride(from: 30, through: 300, by: 15))
    public static let restOptions = Array(stride(from: 0, through: 120, by: 15))

    public func clamped() -> Workout {
        var w = self
        w.rounds = min(max(rounds, Self.roundsRange.lowerBound), Self.roundsRange.upperBound)
        w.work = min(max(work, Self.workOptions.first!), Self.workOptions.last!)
        w.rest = min(max(rest, Self.restOptions.first!), Self.restOptions.last!)
        return w
    }

    /// Work plus the rests BETWEEN rounds: 2 x 2:00 + 1 x 0:30 = 4:30.
    public var totalSeconds: Int {
        rounds * work + max(0, rounds - 1) * rest
    }

    /// Which countdown drill closes round `round` (1-based), if any. With both
    /// on, Muay Thai alternates: punches, kicks, punches…
    public func countdownDrill(round: Int) -> CountdownDrill? {
        var drills: [CountdownDrill] = []
        if punchCountdown { drills.append(.punches) }
        if kickCountdown && discipline == .muayThai { drills.append(.kicks) }
        guard !drills.isEmpty, work >= CountdownDrill.minimumWork else { return nil }
        return drills[(round - 1) % drills.count]
    }
}

public enum CountdownDrill: String, Sendable, Equatable {
    case punches, kicks
    public var title: String { self == .punches ? "PUNCHES" : "KICKS" }
    /// Seconds the drill takes at the end of a round.
    public static let length = 10
    /// A round shorter than this has no room for combos before the drill.
    public static let minimumWork = 20
}

public extension Workout {
    /// The defaults, matching the phone app.
    static let defaults: [Workout] = [
        Workout(id: "speed-demon", name: "Speed Demon", discipline: .boxing,
                rounds: 2, work: 120, rest: 30, intensity: .high,
                callout: .names, defense: false, punchCountdown: true),
        Workout(id: "creative-flow", name: "Creative Flow", discipline: .boxing,
                rounds: 3, work: 120, rest: 30, intensity: .medium,
                callout: .numbers, defense: true),
        Workout(id: "eight-limbs", name: "Eight Limbs", discipline: .muayThai,
                rounds: 3, work: 180, rest: 60, intensity: .medium,
                callout: .names, punchCountdown: true, kickCountdown: true),
    ]
}

/// Clock-style durations, always with seconds: "4:30", "0:30", "1:02:30".
/// Never "5m", never "0m".
public enum DurationFormat {
    public static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return "\(h):" + pad(m) + ":" + pad(sec) }
        return "\(m):" + pad(sec)
    }

    /// For a live countdown: rounds UP, so the ring reads 0:01 for the whole
    /// last second rather than 0:00 before the bell.
    public static func countdown(_ seconds: TimeInterval) -> String {
        clock(Int(max(0, seconds).rounded(.up)))
    }

    private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
