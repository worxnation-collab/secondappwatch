import SwiftUI
import RoundCore

/// Everything is a Picker or a Toggle: on the watch a Picker opens a list the
/// Digital Crown scrolls, which is the fastest way to set 2:30 with a glove
/// half on.
struct WorkoutSettingsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var health: HealthSession
    @State private var draft: Workout
    @State private var running: Workout?

    init(workout: Workout) {
        _draft = State(initialValue: workout)
    }

    var body: some View {
        List {
            VStack(spacing: 0) {
                Text(DurationFormat.clock(draft.totalSeconds))
                    .font(.rounded(34, .heavy)).monospacedDigit()
                    .foregroundStyle(Theme.gradient)
                Text(draft.shape).font(.rounded(12, .semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)

            Button { running = draft } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Picker("Rounds", selection: $draft.rounds) {
                ForEach(Array(Workout.roundsRange), id: \.self) { Text("\($0)").tag($0) }
            }
            Picker("Work", selection: $draft.work) {
                ForEach(Workout.workOptions, id: \.self) { Text(DurationFormat.clock($0)).tag($0) }
            }
            Picker("Rest", selection: $draft.rest) {
                ForEach(Workout.restOptions, id: \.self) { Text(DurationFormat.clock($0)).tag($0) }
            }
            Picker("Intensity", selection: $draft.intensity) {
                ForEach(Intensity.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Combos", selection: $draft.comboSource) {
                ForEach(ComboSource.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if draft.comboSource == .generated {
                Toggle("Defense", isOn: $draft.defense)
                Toggle("Body shots", isOn: $draft.bodyShots)
            } else if store.myCombos.isEmpty {
                Text("No combos saved yet, so this round will generate them.")
                    .font(.rounded(12, .semibold)).foregroundStyle(.secondary)
            }
            Picker("Call as", selection: $draft.callout) {
                ForEach(CalloutStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle("Punch countdown", isOn: $draft.punchCountdown)
            if draft.discipline == .muayThai {
                Toggle("Kick countdown", isOn: $draft.kickCountdown)
            }

            Section {
                if health.access == .denied || health.access == .unavailable {
                    Label("Health is off: the timer still runs, but no heart rate or save.",
                          systemImage: "heart.slash")
                        .font(.rounded(12, .semibold)).foregroundStyle(.secondary)
                }
                if Workout.defaults.contains(where: { $0.id == draft.id }) {
                    Button("Reset to default") {
                        if let d = store.resetToDefault(draft.id) { draft = d }
                    }
                    .font(.rounded(14, .semibold))
                }
            } footer: {
                Text("Intensity sets how often combos are called and how long they are. Defense adds slips, rolls, ducks, pulls, parries and a pivot out. A countdown turns a round's last 10 seconds into one punch per second.")
            }
        }
        .navigationTitle(draft.name)
        .onChange(of: draft) { store.update($0) }
        .fullScreenCover(item: $running) { workout in
            RunView(workout: workout, health: health, mine: store.myCombos)
        }
    }
}
