import SwiftUI

@main
struct TuTuMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("TuTuMac") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
