import Foundation
import RoundCore

/// Drives one run: the engine on a 10Hz clock, the haptics, and the Health
/// session beside it. Monotonic time (systemUptime), so a clock change
/// mid-round can't stretch a round.
@MainActor
final class RunModel: ObservableObject {
    @Published private(set) var status: Status
    @Published private(set) var finished = false
    @Published private(set) var roundsDone = 0

    let workout: Workout
    let health: HealthSession
    private var engine: WorkoutEngine
    private var timer: Timer?

    init(workout: Workout, health: HealthSession, seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)) {
        self.workout = workout
        self.health = health
        engine = WorkoutEngine(workout: workout, seed: seed)
        status = engine.status(at: 0)
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var isPaused: Bool { engine.state == .paused }

    func start() {
        guard engine.state == .ready else { return }
        let discipline = workout.discipline
        Task { await health.begin(discipline) }
        play(engine.start(at: now))
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func togglePause() {
        if engine.state == .paused {
            play(engine.resume(at: now))
            health.resume()
        } else {
            play(engine.pause(at: now))
            health.pause()
        }
    }

    func end() {
        play(engine.end(at: now))
    }

    /// Back in the foreground: settle whatever the clock passed.
    func resync() { tick() }

    private func tick() { play(engine.tick(at: now)) }

    private func play(_ cues: [Cue]) {
        for cue in cues { if case .bell = cue { roundsDone += 1 } }
        if !cues.isEmpty { Haptics.play(cues) }
        status = engine.status(at: now)
        if engine.state == .finished && !finished { finish() }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        finished = true
        Task { await health.end() }
    }
}
