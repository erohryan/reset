import SwiftUI

/// 1. Welcome
struct WelcomeView: View {
    @Environment(LockEngine.self) private var engine

    var body: some View {
        ScreenFrame {
            Wordmark(size: 24)
            PuckView(label: "")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            StatusLine(text: "// a puck for your phone")
            Headline(text: "Give your apps a nap.", size: 46)
            BodyText(text: "Tap your phone on the puck and the apps you choose go to sleep. Tap again to wake them.")
            Button("Pair a puck") { engine.startPairing() }
                .buttonStyle(.primary)
                .padding(.top, 8)
        }
    }
}
