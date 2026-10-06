import SwiftUI

/// Switches between the main-flow screens and applies the puck's casing.
struct RootView: View {
    @Environment(LockEngine.self) private var engine

    var body: some View {
        ZStack {
            switch engine.route {
            case .welcome: WelcomeView().screenTransition()
            case .pair: PairView().screenTransition()
            case .pick: PickAppsView().screenTransition()
            case .tapSetup: TapSetupView().screenTransition()
            case .ready: ReadyView().screenTransition()
            case .resting: RestingView().screenTransition()
            case .wake: WakeView().screenTransition()
            }
        }
        .environment(\.casing, engine.casing)
        .animation(Theme.screenIn, value: engine.route)
        .sensoryFeedback(.impact(weight: .medium), trigger: engine.route) { _, new in
            new == .resting || new == .wake
        }
    }
}
