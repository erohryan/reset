import SwiftUI

/// Guides the one-time Shortcuts automation that makes a puck tap-only: tap the puck
/// with reset closed and it rests or wakes. Optionally pairs it with a Focus so chosen
/// people can still reach you. iOS doesn't let apps create automations, so these are steps.
struct TapSetupView: View {
    @Environment(LockEngine.self) private var engine
    @Environment(\.openURL) private var openURL
    @State private var showingFocus = false

    private var puckName: String { engine.tapSetupPuck?.name ?? "your" }
    private var isOnboarding: Bool { engine.pucks.count == 1 && engine.tapSetupPuck?.tapOnlyReady == false }

    var body: some View {
        ScreenFrame(spacing: 12) {
            HStack {
                MonoLink(title: "maybe later") { engine.finishTapSetup(done: false) }
                Spacer()
                if isOnboarding { Text("03 / 03").font(RFont.label).foregroundStyle(Theme.subtle) }
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    StatusLine(text: "// \(puckName.lowercased()).mode = tap_only")
                    Headline(text: "Skip the button.")
                    BodyText(text: "Set up a one-time automation and a tap on your \(puckName) puck is all it takes, even with reset closed.", size: 14)

                    StepsCard(steps: [
                        "Open **Shortcuts**, go to **Automation**, tap **+** and choose **NFC**.",
                        "Tap **Scan**, hold your phone to the **\(puckName)** puck, and name it \"\(puckName)\".",
                        "Choose **Run Immediately**, then **Next** → **Create New Shortcut**.",
                        "Search for **reset** and add **Rest or wake**.",
                        "Tap **Done**, then tap the puck to try it.",
                    ])

                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showingFocus.toggle() }
                    } label: {
                        HStack {
                            StatusLine(text: "// optional: let some people through", size: 11)
                            Spacer()
                            Text(showingFocus ? "–" : "+").font(RFont.label)
                        }
                    }
                    .buttonStyle(.plain)

                    if showingFocus {
                        BodyText(text: "Napping apps can still send notifications. A Focus can silence everyone except the people you choose, in Messages, calls and apps that support it, like WhatsApp.", size: 14)
                        StepsCard(steps: [
                            "In **Settings** → **Focus**, tap **+** → **Custom** and name it **reset**. Under **People**, allow who can still reach you.",
                            "Back in this puck's automation, after **Rest or wake** add **If**: *Rest or wake* **is** `resting`.",
                            "Inside **If**, add **Set Focus** → **reset** → **On**. Under **Otherwise**, add **Set Focus** → **reset** → **Off**.",
                        ])
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }

            Button("Open Shortcuts") {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            }
            .buttonStyle(.primary)
            Button("I've set it up") { engine.finishTapSetup(done: true) }
                .buttonStyle(.secondary)
        }
    }
}

/// Numbered steps in an ink card: "01  Open Shortcuts…"
struct StepsCard: View {
    var steps: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(RFont.caption)
                        .foregroundStyle(Theme.subtle)
                    Text(step)
                        .font(RFont.body(14))
                        .foregroundStyle(Theme.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .overlay(alignment: .bottom) {
                    if index < steps.count - 1 { DashedDivider() }
                }
            }
        }
        .inkCard(radius: Theme.Radius.cardL)
    }
}
