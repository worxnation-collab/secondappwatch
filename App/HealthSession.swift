import Foundation
import HealthKit
import RoundCore

/// Outside the main-actor class so the builder delegate, which HealthKit
/// calls off the main thread, can read them.
private enum HealthTypes {
    static let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let bpm = HKUnit.count().unitDivided(by: .minute())
}

/// One HKWorkoutSession + HKLiveWorkoutBuilder per run.
///
/// The session is what keeps the app alive with the wrist down (and so what
/// keeps the haptics firing); the builder collects heart rate and active
/// energy and saves the workout. Everything here fails soft: no Health, no
/// permission, or a session that won't start all leave the timer running
/// exactly as before. Health is a bonus on top of the drill, never a gate.
@MainActor
final class HealthSession: NSObject, ObservableObject {
    enum Access: Equatable { case unknown, granted, denied, unavailable }

    @Published private(set) var access: Access = .unknown
    /// Beats per minute, most recent sample.
    @Published private(set) var heartRate: Double?
    /// Active kilocalories this session.
    @Published private(set) var calories: Double = 0
    @Published private(set) var isLive = false
    /// After `end`: whether the workout made it into Health.
    @Published private(set) var saved = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// Asks once. HealthKit never re-prompts, so calling this again is cheap.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            access = .unavailable
            return
        }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HealthTypes.energy, HealthTypes.heartRate]
        let read: Set<HKObjectType> = [HealthTypes.heartRate, HealthTypes.energy]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
        } catch {
            access = .denied
            return
        }
        // Read access is private by design; the workout share status is the
        // one HealthKit will tell us.
        access = store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized ? .granted : .denied
    }

    func begin(_ discipline: Discipline) async {
        heartRate = nil
        calories = 0
        saved = false
        if access == .unknown { await requestAuthorization() }
        guard access == .granted else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = discipline == .boxing ? .boxing : .martialArts
        config.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            isLive = true
        } catch {
            session?.end()
            session = nil
            builder = nil
            isLive = false
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    func end() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: Date())
            saved = try await builder.finishWorkout() != nil
        } catch {
            saved = false
        }
        self.session = nil
        self.builder = nil
        isLive = false
    }

    fileprivate func apply(heartRate: Double?, calories: Double?) {
        if let heartRate { self.heartRate = heartRate }
        if let calories { self.calories = calories }
    }

    fileprivate func sessionFailed() {
        isLive = false
    }
}

extension HealthSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.sessionFailed() }
    }
}

extension HealthSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var hr: Double?
        var kcal: Double?
        if collectedTypes.contains(HealthTypes.heartRate) {
            hr = workoutBuilder.statistics(for: HealthTypes.heartRate)?.mostRecentQuantity()?.doubleValue(for: HealthTypes.bpm)
        }
        if collectedTypes.contains(HealthTypes.energy) {
            kcal = workoutBuilder.statistics(for: HealthTypes.energy)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
        Task { @MainActor in self.apply(heartRate: hr, calories: kcal) }
    }
}
