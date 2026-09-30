import Foundation
import RoundCore
#if os(watchOS)
import WatchKit
#endif

/// The only file that touches the Taptic Engine. WHICH pulse plays WHEN is
/// decided in RoundCore; this plays the beats on time. Inside a workout
/// session the app keeps running with the wrist down, so these still land.
enum Haptics {
    static func play(_ cues: [Cue]) {
        for cue in cues {
            for beat in cue.pattern {
                if beat.at == 0 { fire(beat.pulse) } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + beat.at) { fire(beat.pulse) }
                }
            }
        }
    }

    private static func fire(_ pulse: Pulse) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(pulse.hapticType)
        #endif
    }
}

#if os(watchOS)
private extension Pulse {
    var hapticType: WKHapticType {
        switch self {
        case .start: return .start
        case .click: return .click
        case .directionUp: return .directionUp
        case .notification: return .notification
        case .stop: return .stop
        case .success: return .success
        }
    }
}
#endif
