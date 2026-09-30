import Foundation

/// What the run screen draws, derived purely from the plan and the time.
public struct Status: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case getReady
        case work(round: Int)
        case rest(nextRound: Int)
        case done
    }

    public struct DrillCount: Sendable, Equatable {
        public let drill: CountdownDrill
        public let count: Int
    }

    public let phase: Phase
    /// Seconds left in the current segment.
    public let remaining: TimeInterval
    public let length: TimeInterval
    /// The combo on screen: the latest one called in this round.
    public let combo: Combo?
    /// Set during the last ten seconds of a round that ends in a drill.
    public let drill: DrillCount?
    public let isPaused: Bool
    /// Seconds of the workout itself done so far (get-ready excluded).
    public let activeSeconds: TimeInterval

    /// 1 when the segment starts, 0 at its end.
    public var fraction: Double { length > 0 ? max(0, min(1, remaining / length)) : 0 }
}

/// The workout as a state machine over an injected clock. Every call returns
/// the cues it produced and the caller plays them; nothing in here owns a
/// timer, which is what makes it testable to the millisecond.
///
/// The clock is wall time. If the app is starved (it shouldn't be, inside a
/// workout session, but watchOS is watchOS), the next `tick` catches up:
/// structural cues (round start, bell, done) still play, and anything more
/// than `staleAfter` old is dropped, because a combo tapped five seconds late
/// is a combo you can't throw.
public struct WorkoutEngine: Sendable {
    public enum State: Sendable, Equatable { case ready, running, paused, finished }

    public static let staleAfter: TimeInterval = 1

    public let plan: WorkoutPlan
    public var workout: Workout { plan.workout }
    public private(set) var state: State = .ready

    /// Wall time that maps to t = 0 on the plan. Pausing moves it.
    private var origin: TimeInterval = 0
    private var pausedAt: TimeInterval?
    private var endedAt: TimeInterval?
    private var nextCue = 0

    public init(workout: Workout, seed: UInt64, mine: [Combo] = []) {
        plan = WorkoutPlan(workout: workout, seed: seed, mine: mine)
    }

    public mutating func start(at now: TimeInterval) -> [Cue] {
        guard state == .ready else { return [] }
        origin = now
        state = .running
        return tick(at: now)
    }

    public mutating func tick(at now: TimeInterval) -> [Cue] {
        guard state == .running else { return [] }
        let t = now - origin
        var out: [Cue] = []
        while nextCue < plan.cues.count, plan.cues[nextCue].at <= t {
            let timed = plan.cues[nextCue]
            if timed.cue.isStructural || t - timed.at <= Self.staleAfter {
                out.append(timed.cue)
            }
            nextCue += 1
        }
        if t >= plan.duration {
            state = .finished
            endedAt = plan.duration
        }
        return out
    }

    public mutating func pause(at now: TimeInterval) -> [Cue] {
        let cues = tick(at: now)
        guard state == .running else { return cues }
        state = .paused
        pausedAt = now
        return cues
    }

    public mutating func resume(at now: TimeInterval) -> [Cue] {
        guard state == .paused, let pausedAt else { return [] }
        origin += now - pausedAt
        self.pausedAt = nil
        state = .running
        return tick(at: now)
    }

    /// Stop early. The workout still counts; this is the same `done` a full
    /// workout ends on.
    public mutating func end(at now: TimeInterval) -> [Cue] {
        guard state == .running || state == .paused else { return [] }
        endedAt = min(elapsed(at: now), plan.duration)
        state = .finished
        pausedAt = nil
        return [.done]
    }

    /// Plan time at `now`: frozen while paused, clamped to the plan.
    public func elapsed(at now: TimeInterval) -> TimeInterval {
        switch state {
        case .ready: return 0
        case .finished: return endedAt ?? plan.duration
        case .paused: return max(0, min(plan.duration, (pausedAt ?? now) - origin))
        case .running: return max(0, min(plan.duration, now - origin))
        }
    }

    public func status(at now: TimeInterval) -> Status {
        let t = elapsed(at: now)
        let active = max(0, t - WorkoutPlan.getReady)
        guard state != .finished, let seg = plan.segment(at: t) else {
            return Status(phase: .done, remaining: 0, length: 0, combo: nil, drill: nil,
                          isPaused: false, activeSeconds: active)
        }
        let remaining = seg.end - t
        switch seg.kind {
        case .getReady:
            return Status(phase: .getReady, remaining: remaining, length: seg.length, combo: nil,
                          drill: nil, isPaused: state == .paused, activeSeconds: active)
        case .rest(let next):
            return Status(phase: .rest(nextRound: next), remaining: remaining, length: seg.length,
                          combo: nil, drill: nil, isPaused: state == .paused, activeSeconds: active)
        case .work(let round):
            var drill: Status.DrillCount?
            if let kind = workout.countdownDrill(round: round), remaining <= Double(CountdownDrill.length) {
                drill = Status.DrillCount(drill: kind, count: Int(remaining.rounded(.up)))
            }
            return Status(phase: .work(round: round), remaining: remaining, length: seg.length,
                          combo: drill == nil ? currentCombo(in: seg, at: t) : nil, drill: drill,
                          isPaused: state == .paused, activeSeconds: active)
        }
    }

    private func currentCombo(in seg: Segment, at t: TimeInterval) -> Combo? {
        var found: Combo?
        for timed in plan.cues {
            if timed.at > t { break }
            if timed.at >= seg.start, case .combo(let combo) = timed.cue { found = combo }
        }
        return found
    }
}
