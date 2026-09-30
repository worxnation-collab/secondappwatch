import SwiftUI
import RoundCore

struct MyCombosView: View {
    @EnvironmentObject private var store: WorkoutStore

    var body: some View {
        List {
            NavigationLink(value: Route.buildCombo) {
                Label("Build a combo", systemImage: "plus.circle.fill")
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(Theme.orange)
            }
            ForEach(Array(store.myCombos.enumerated()), id: \.offset) { _, combo in
                Button { Haptics.play([.combo(combo)]) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(combo.callout(.numbers)).font(.rounded(18, .heavy))
                        Text(combo.callout(.names)).font(.rounded(10, .semibold)).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .accessibilityHint("Plays the combo as taps")
            }
            .onDelete { store.removeCombos(at: $0) }

            Text("Tap a combo to feel it. Swipe left to delete. Set a workout's Combos to \"My combos\" to drill these.")
                .font(.rounded(11, .semibold)).foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
        .navigationTitle("My Combos")
    }
}

/// Build a combo by tapping moves in order. Every key clicks, and "Feel it"
/// plays the combo exactly as a round will call it.
struct ComboBuilderView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var moves: [Move] = []

    private static let rows: [[Move]] = [
        [.jab, .cross, .leadHook],
        [.rearHook, .leadUppercut, .rearUppercut],
        [.bodyJab, .bodyCross, .bodyHook],
        [.bodyRearHook, .slip, .roll],
        [.duck, .pull, .parry],
        [.pivot],
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(moves.isEmpty ? "Tap moves" : Combo(moves).callout(.numbers))
                    .font(.rounded(moves.isEmpty ? 16 : 26, .black))
                    .foregroundStyle(moves.isEmpty ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Theme.gradient))
                    .lineLimit(2).minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, minHeight: 36)

                ForEach(Self.rows.indices, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(Self.rows[r], id: \.self) { move in
                            MoveKey(move: move, enabled: moves.count < Combo.maxBuiltLength) {
                                moves.append(move)
                                Haptics.tap()
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Button { _ = moves.popLast() } label: { Image(systemName: "delete.left.fill") }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(moves.isEmpty)
                        .accessibilityLabel("Undo")
                    Button { Haptics.play([.combo(Combo(moves))]) } label: { Image(systemName: "waveform") }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(moves.isEmpty)
                        .accessibilityLabel("Feel it")
                }
                Button("Save") {
                    store.addCombo(Combo(moves))
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(moves.isEmpty)
                .opacity(moves.isEmpty ? 0.4 : 1)
            }
        }
        .navigationTitle("New Combo")
    }
}

private struct MoveKey: View {
    let move: Move
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(move.code ?? move.name)
                .font(.rounded(move.code == nil ? 11 : 17, .heavy))
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(move.kind == .punch ? .white : Theme.pink)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(move.name.capitalized)
    }
}
