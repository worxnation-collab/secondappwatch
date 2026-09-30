import Foundation

public struct Segment: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case getReady
        case work(round: Int)
        case rest(nextRound: Int)
    }
    public let kind: Kind
    public let start: TimeInterval
    public let end: TimeInterval
    public var length: TimeInterval { end - start }
}

public struct TimedCue: Sendable, Equatable {
    public let at: TimeInterval
    public let cue: Cue
}

/// The whole workout written out in advance: every segment and every cue, on
/// a timeline that starts at 0 with the get-ready. Nothing in here knows what
/// time it is; `WorkoutEngine` walks it against a clock.
///
/// Writing it out up front is what makes a workout checkable: the tests read
/// the timeline and assert the exact cues, down to the second.
public struct WorkoutPlan: Sendable {
    /// Seconds between tapping Start and the first bell.
    public static let getReady: TimeInterval = 5
    /// The first combo of a round waits for the round-start tap to finish.
    public static let firstCall: TimeInterval = 2
    /// No combo in the last seconds of a round: nobody starts a 1-2-3-2 at
    /// the bell.
    public static let tail: TimeInterval = 2.5
    /// Keep combos this far clear of the 10-second tap, or the two blur.
    public static let clearance: TimeInterval = 1
    /// The "get set" ticks at the end of the get-ready and every rest.
    public static let getSetTicks = 3

    public let workout: Workout
    public let segments: [Segment]
    public let cues: [TimedCue]

    /// Get-ready included.
    public var duration: TimeInterval { segments.last?.end ?? 0 }

    public init(workout input: Workout, seed: UInt64) {
        let workout = input.clamped()
        self.workout = workout
        var generator = ComboGenerator(workout: workout, seed: seed)
        var segments: [Segment] = []
        var cues: [TimedCue] = []

        func getSet(before end: TimeInterval, length: TimeInterval) {
            for n in stride(from: Self.getSetTicks, through: 1, by: -1) where Double(n) <= length {
                cues.append(TimedCue(at: end - Double(n), cue: .getSet(secondsLeft: n)))
            }
        }

        segments.append(Segment(kind: .getReady, start: 0, end: Self.getReady))
        getSet(before: Self.getReady, length: Self.getReady)

        var t = Self.getReady
        for round in 1...workout.rounds {
            let work = Double(workout.work)
            let end = t + work
            let drill = workout.countdownDrill(round: round)
            segments.append(Segment(kind: .work(round: round), start: t, end: end))
            cues.append(TimedCue(at: t, cue: .roundStart(round: round)))

            let ten = Double(CountdownDrill.length)
            var call = t + Self.firstCall
            while call < end {
                let left = end - call
                let clear = drill != nil
                    ? left >= ten + Self.clearance
                    : (work <= ten || abs(left - ten) >= Self.clearance)
                if left > Self.tail && clear {
                    cues.append(TimedCue(at: call, cue: .combo(generator.next())))
                }
                call += workout.intensity.callInterval
            }
            if work > ten {
                cues.append(TimedCue(at: end - ten, cue: .tenSeconds))
            }
            if let drill {
                for n in stride(from: CountdownDrill.length - 1, through: 1, by: -1) {
                    cues.append(TimedCue(at: end - Double(n), cue: .count(n, drill)))
                }
            }
            cues.append(TimedCue(at: end, cue: .bell(round: round)))

            if round == workout.rounds {
                cues.append(TimedCue(at: end, cue: .done))
                t = end
            } else {
                let rest = Double(workout.rest)
                if rest > 0 {
                    segments.append(Segment(kind: .rest(nextRound: round + 1), start: end, end: end + rest))
                    getSet(before: end + rest, length: rest)
                }
                t = end + rest
            }
        }

        // Order by time, then by the order written, so a bell always comes
        // before the `done` that shares its instant.
        self.segments = segments
        self.cues = cues.enumerated()
            .sorted { $0.element.at != $1.element.at ? $0.element.at < $1.element.at : $0.offset < $1.offset }
            .map(\.element)
    }

    public func segment(at t: TimeInterval) -> Segment? {
        segments.first { t >= $0.start && t < $0.end }
    }
}
