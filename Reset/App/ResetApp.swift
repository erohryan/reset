import SwiftUI

@main
struct ResetApp: App {
    @State private var environment = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.engine)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            // The Shortcuts automation may have toggled reset while we were away.
            if phase == .active { environment.engine.reload() }
        }
    }
}
