import Foundation
import RoundCore

/// The workouts, as edited on the watch. Stored as JSON in UserDefaults; a
/// stored workout is clamped on the way in so a bad value can't build a
/// 0-round workout, and any default the store doesn't know yet is added.
@MainActor
final class WorkoutStore: ObservableObject {
    private static let key = "workouts.v1"
    private let defaults: UserDefaults

    @Published private(set) var workouts: [Workout]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded: [Workout] = []
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            loaded = decoded.map { $0.clamped() }
        }
        for d in Workout.defaults where !loaded.contains(where: { $0.id == d.id }) {
            loaded.append(d)
        }
        workouts = loaded
    }

    func workouts(for discipline: Discipline) -> [Workout] {
        workouts.filter { $0.discipline == discipline }
    }

    func update(_ workout: Workout) {
        guard let i = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[i] = workout.clamped()
        save()
    }

    func resetToDefault(_ id: String) -> Workout? {
        guard let d = Workout.defaults.first(where: { $0.id == id }) else { return nil }
        update(d)
        return d
    }

    private func save() {
        if let data = try? JSONEncoder().encode(workouts) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
