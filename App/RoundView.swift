import SwiftUI
import RoundCore

struct RoundView: View {
    @StateObject private var model = RoundModel()
    @AppStorage("crownMode") private var crownMode = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.engine.phase {
            case .ready: ReadyView(crownMode: $crownMode, start: model.start)
            case .asking(let i):
                if crownMode {
                    // .id gives each question a fresh crown at the middle.
                    CrownAskingView(model: model, index: i).id(i)
                } else {
                    AskingView(model: model, index: i)
                }
            case .feedback(_, let result): FeedbackView(result: result, combo: model.engine.combo, next: model.next)
            case .finished: FinishedView(engine: model.engine, again: model.playAgain)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.resync() }
        }
    }
}

private let gold = Color(red: 1.0, green: 0.78, blue: 0.29)

private struct ReadyView: View {
    @Binding var crownMode: Bool
    let start: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Combo Clock").font(.headline)
                Text("\(RoundModel.questionsPerRound) questions · \(Int(Scoring().answerWindow))s each")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Feel your streak: one tap per combo level.")
                    .font(.caption2).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Toggle("Answer with the Crown", isOn: $crownMode).font(.footnote)
                if crownMode {
                    Text("Turn up for True, down for False. A click means it's armed; turn to the stop to answer.")
                        .font(.caption2).multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                Button("Start", action: start).tint(gold)
            }
        }
    }
}

private struct AskingView: View {
    @ObservedObject var model: RoundModel
    let index: Int

    var body: some View {
        let engine = model.engine
        let window = engine.scoring.answerWindow
        VStack(spacing: 4) {
            HStack {
                Text("\(index + 1)/\(engine.cards.count)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if engine.combo >= 1 {
                    Text("×" + engine.multiplier.formatted(.number.precision(.fractionLength(0...2))))
                        .font(.caption2.bold()).foregroundStyle(gold)
                }
                ClockRing(fraction: model.remaining / window, seconds: Int(model.remaining.rounded(.up)))
            }
            Text(engine.cards[index].prompt)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxHeight: .infinity)
            HStack(spacing: 6) {
                Button("True") { model.answer(true) }.tint(.green)
                Button("False") { model.answer(false) }.tint(.pink)
            }
        }
    }
}

/// The same question, answered by turning the Digital Crown. Up is True,
/// down is False; `CrownDial` decides when a turn arms and when it commits.
/// The two rows are still buttons, so a tap works here too.
private struct CrownAskingView: View {
    @ObservedObject var model: RoundModel
    let index: Int
    @State private var crown = 0.0
    @FocusState private var focused: Bool

    var body: some View {
        let engine = model.engine
        let window = engine.scoring.answerWindow
        VStack(spacing: 4) {
            HStack {
                Text("\(index + 1)/\(engine.cards.count)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if engine.combo >= 1 {
                    Text("×" + engine.multiplier.formatted(.number.precision(.fractionLength(0...2))))
                        .font(.caption2.bold()).foregroundStyle(gold)
                }
                ClockRing(fraction: model.remaining / window, seconds: Int(model.remaining.rounded(.up)))
            }
            CrownOption(label: "▲ True", tint: .green, side: true, dial: model.dial) { model.answer(true) }
            Text(engine.cards[index].prompt)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxHeight: .infinity)
            CrownOption(label: "▼ False", tint: .pink, side: false, dial: model.dial) { model.answer(false) }
        }
        .focusable()
        .focused($focused)
        .digitalCrownRotation($crown, from: -1, through: 1, by: 0.01,
                              sensitivity: .low, isContinuous: false,
                              isHapticFeedbackEnabled: false)
        .onChange(of: crown) { value in model.crown(value) }
        .onAppear { focused = true }
    }
}

private struct CrownOption: View {
    let label: String
    let tint: Color
    let side: Bool
    let dial: CrownDial
    let action: () -> Void

    var body: some View {
        let armed = dial.armed == side
        // Fills from the arm point to the commit stop, so you can see how far
        // is left to turn.
        let span = CrownDial.commitAt - CrownDial.armAt
        let fill = armed ? min(1, max(0, (dial.travel - CrownDial.armAt) / span)) : 0
        Button(action: action) {
            Text(label)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(alignment: .leading) {
                    GeometryReader { g in
                        tint.opacity(0.55).frame(width: g.size.width * fill)
                    }
                }
                .background(tint.opacity(armed ? 0.3 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(armed ? tint : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct ClockRing: View {
    let fraction: Double
    let seconds: Int
    var body: some View {
        ZStack {
            Circle().stroke(.gray.opacity(0.3), lineWidth: 3)
            Circle().trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(seconds <= 3 ? .orange : gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: fraction)
            Text("\(seconds)").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .frame(width: 26, height: 26)
    }
}

private struct FeedbackView: View {
    let result: QuestionResult
    let combo: Int
    let next: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                switch result.outcome {
                case .correct:
                    Text(combo >= 2 ? "Combo ×\(combo)" : "Right!").font(.headline).foregroundStyle(gold)
                    Text("+\(result.points)").font(.title3.bold()).monospacedDigit()
                case .wrong:
                    Text("Now you know").font(.headline)
                case .timedOut:
                    Text("Time — now you know").font(.headline)
                }
                Text(result.card.teach).font(.caption).multilineTextAlignment(.center)
                Button("Next", action: next)
            }
        }
    }
}

private struct FinishedView: View {
    let engine: RoundEngine
    let again: () -> Void

    var body: some View {
        let learned = engine.results.filter { $0.outcome != .correct }.count
        ScrollView {
            VStack(spacing: 6) {
                Text("\(engine.score)").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(gold)
                Text("Best combo ×\(engine.comboMax)").font(.footnote)
                if learned > 0 {
                    // The misses are framed as what was learned, never as failures.
                    Text(learned == 1 ? "1 thing you now know" : "\(learned) things you now know")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Button("Play again", action: again).tint(gold)
            }
        }
    }
}
