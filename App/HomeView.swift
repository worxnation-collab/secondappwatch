import SwiftUI
import RoundCore

enum Route: Hashable {
    case workout(String)
    case myCombos
    case buildCombo
}

/// Boxing only, for now. Muay Thai is fully built in RoundCore (moves, rules,
/// kick countdowns, its default workout, tests) and is one filter away from
/// coming back; the watch shows one discipline, done properly.
struct HomeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var health: HealthSession

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 6) {
                    Image(systemName: Discipline.boxing.symbol).font(.system(size: 16, weight: .bold))
                    Text("BOXING").font(.rounded(14, .heavy))
                }
                .foregroundStyle(Theme.gradient)
                .listRowBackground(Color.clear)

                ForEach(store.workouts(for: .boxing)) { workout in
                    NavigationLink(value: Route.workout(workout.id)) {
                        WorkoutRow(workout: workout)
                    }
                    .listRowBackground(Theme.panel.clipShape(RoundedRectangle(cornerRadius: 14)))
                }

                NavigationLink(value: Route.myCombos) {
                    HStack {
                        Image(systemName: "hand.raised.fingers.spread.fill").foregroundStyle(Theme.pink)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("My Combos").font(.rounded(15, .heavy))
                            Text("\(store.myCombos.count) saved").font(.rounded(12, .semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Theme.panel.clipShape(RoundedRectangle(cornerRadius: 14)))
            }
            .navigationTitle("Combo Clock")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .workout(let id):
                    if let workout = store.workouts.first(where: { $0.id == id }) {
                        WorkoutSettingsView(workout: workout)
                    }
                case .myCombos: MyCombosView()
                case .buildCombo: ComboBuilderView()
                }
            }
        }
        // Ask on the home screen, not over a running countdown.
        .task { if health.access == .unknown { await health.requestAuthorization() } }
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.name).font(.rounded(16, .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(DurationFormat.clock(workout.totalSeconds))
                    .font(.rounded(16, .heavy)).monospacedDigit()
                    .foregroundStyle(Theme.gradient)
            }
            Text(workout.shape).font(.rounded(12, .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                IntensityBadge(intensity: workout.intensity)
                if workout.comboSource == .mine {
                    Text("MINE").font(.rounded(10, .heavy)).foregroundStyle(Theme.pink)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct IntensityBadge: View {
    let intensity: Intensity

    var body: some View {
        let level = Intensity.allCases.firstIndex(of: intensity)! + 1
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(i <= level ? Theme.orange : Color(white: 0.3))
            }
            Text(intensity.title).font(.rounded(11, .bold)).foregroundStyle(.secondary)
        }
    }
}
