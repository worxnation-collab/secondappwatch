import SwiftUI

/// OOWEE's look, as a concept: black, a pink-to-orange accent, orange
/// primary buttons, rounded bold type.
enum Theme {
    static let pink = Color(red: 1, green: 0x5F / 255, blue: 0xA2 / 255)    // #FF5FA2
    static let orange = Color(red: 1, green: 0x4A / 255, blue: 0x1C / 255)  // #FF4A1C
    static let gradient = LinearGradient(colors: [pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let rest = Color(white: 0.6)
    static let panel = Color(white: 0.13)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(17, .heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.orange, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(16, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.panel, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension Discipline {
    var symbol: String { self == .boxing ? "figure.boxing" : "figure.kickboxing" }
}

extension Workout {
    /// "2 × 2:00 · 0:30 rest"
    var shape: String {
        let base = "\(rounds) × \(DurationFormat.clock(work))"
        return rest > 0 && rounds > 1 ? base + " · \(DurationFormat.clock(rest)) rest" : base
    }
}
