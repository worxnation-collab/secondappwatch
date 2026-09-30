import SwiftUI

@main
struct ComboClockApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var health = HealthSession()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(health)
                .tint(Theme.orange)
        }
    }
}
