import SwiftUI
import RoundCore

struct HomeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var health: HealthSession
    @AppStorage("discipline") private var discipline: Discipline = .boxing

    var body: some View {
        NavigationStack {
            List {
                DisciplineToggle(selection: $discipline)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                ForEach(store.workouts(for: discipline)) { workout in
                    NavigationLink(value: workout.id) {
                        WorkoutRow(workout: workout)
                    }
                    .listRowBackground(Theme.panel.clipShape(RoundedRectangle(cornerRadius: 14)))
                }
            }
            .navigationTitle("Combo Clock")
            .navigationDestination(for: String.self) { id in
                if let workout = store.workouts.first(where: { $0.id == id }) {
                    WorkoutSettingsView(workout: workout)
                }
            }
        }
        // Ask on the home screen, not over a running countdown.
        .task { if health.access == .unknown { await health.requestAuthorization() } }
    }
}

private struct DisciplineToggle: View {
    @Binding var selection: Discipline

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Discipline.allCases, id: \.self) { d in
                let on = d == selection
                Button { selection = d } label: {
                    VStack(spacing: 2) {
                        Image(systemName: d.symbol).font(.system(size: 18, weight: .bold))
                        Text(d.title).font(.rounded(12, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if on { Capsule().fill(Theme.gradient) } else { Capsule().fill(Theme.panel) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
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
            IntensityBadge(intensity: workout.intensity)
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
