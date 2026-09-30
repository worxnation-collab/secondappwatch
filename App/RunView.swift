import SwiftUI
import RoundCore

/// The run: swipe right from the face for Pause / End, as in Apple's Workout
/// app. No close button, so a sweaty palm can't dismiss a round.
struct RunView: View {
    @StateObject private var model: RunModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 1

    init(workout: Workout, health: HealthSession) {
        _model = StateObject(wrappedValue: RunModel(workout: workout, health: health))
    }

    var body: some View {
        Group {
            if model.finished {
                SummaryView(model: model, health: model.health) { dismiss() }
            } else {
                TabView(selection: $page) {
                    ControlsView(model: model) { page = 1 }.tag(0)
                    RunFace(model: model, health: model.health).tag(1)
                }
                .tabViewStyle(.page)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { model.start() }
        .onChange(of: scenePhase) { if $0 == .active { model.resync() } }
    }
}

private struct RunFace: View {
    @ObservedObject var model: RunModel
    @ObservedObject var health: HealthSession

    var body: some View {
        let s = model.status
        VStack(spacing: 2) {
            HStack {
                Text(roundLabel(s)).font(.rounded(15, .heavy)).monospacedDigit()
                Spacer()
                Metric(symbol: "heart.fill", value: health.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
            }
            ZStack {
                Ring(fraction: s.fraction, work: isWork(s))
                VStack(spacing: 0) {
                    Text(phaseLabel(s))
                        .font(.rounded(13, .heavy))
                        .foregroundStyle(isWork(s) ? Theme.pink : Theme.rest)
                    Text(headline(s))
                        .font(.rounded(34, .black))
                        .lineLimit(2)
                        .minimumScaleFactor(0.35)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .id(headline(s))
                        .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    Text(DurationFormat.countdown(s.remaining))
                        .font(.rounded(20, .bold)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(18)
                .animation(.easeOut(duration: 0.15), value: headline(s))
            }
            HStack {
                Metric(symbol: "flame.fill", value: "\(Int(health.calories.rounded()))")
                Spacer()
                if s.isPaused {
                    Text("PAUSED").font(.rounded(12, .heavy)).foregroundStyle(Theme.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func isWork(_ s: Status) -> Bool {
        if case .work = s.phase { return true }
        return false
    }

    private func roundLabel(_ s: Status) -> String {
        let total = model.workout.rounds
        switch s.phase {
        case .work(let r): return "R\(r)/\(total)"
        case .rest(let next): return "R\(next - 1)/\(total)"
        case .getReady: return "R1/\(total)"
        case .done: return "R\(total)/\(total)"
        }
    }

    private func phaseLabel(_ s: Status) -> String {
        switch s.phase {
        case .getReady: return "GET READY"
        case .work: return s.drill.map { $0.drill.title } ?? "WORK"
        case .rest(let next): return "REST · NEXT R\(next)"
        case .done: return "DONE"
        }
    }

    /// The one thing to read mid-punch.
    private func headline(_ s: Status) -> String {
        switch s.phase {
        case .getReady: return "\(Int(s.remaining.rounded(.up)))"
        case .work:
            if let d = s.drill { return "\(d.count)" }
            return s.combo?.callout(model.workout.callout) ?? "FIGHT"
        case .rest: return "REST"
        case .done: return "DONE"
        }
    }
}

private struct Ring: View {
    let fraction: Double
    let work: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Color(white: 0.16), lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(work ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.rest),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: fraction)
        }
    }
}

private struct Metric: View {
    let symbol: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.pink)
            Text(value).font(.rounded(14, .bold)).monospacedDigit()
        }
    }
}

private struct ControlsView: View {
    @ObservedObject var model: RunModel
    let back: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                model.togglePause()
                back()
            } label: {
                Label(model.isPaused ? "Resume" : "Pause",
                      systemImage: model.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(role: .destructive) { model.end() } label: {
                Label("End", systemImage: "xmark")
            }
            .buttonStyle(SecondaryButtonStyle())
            Text(model.health.isLive ? "Recording to Health" : "Timer only: Health is off")
                .font(.rounded(11, .semibold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

private struct SummaryView: View {
    @ObservedObject var model: RunModel
    @ObservedObject var health: HealthSession
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.gradient)
                Text(model.workout.name).font(.rounded(18, .heavy))
                HStack {
                    Stat(label: "TIME", value: DurationFormat.clock(Int(model.status.activeSeconds.rounded())))
                    Stat(label: "ROUNDS", value: "\(model.roundsDone)/\(model.workout.rounds)")
                }
                HStack {
                    Stat(label: "KCAL", value: "\(Int(health.calories.rounded()))")
                    Stat(label: "BPM", value: health.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
                }
                Text(health.saved ? "Saved to Health" : "Not saved to Health")
                    .font(.rounded(12, .semibold)).foregroundStyle(.secondary)
                Button("Done", action: done).buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

private struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value).font(.rounded(20, .heavy)).monospacedDigit()
            Text(label).font(.rounded(10, .bold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}
