import ManagedSettings
import SwiftUI

/// 6. Shield, as shown inside reset when you tap a napping tile.
/// The system shield (ResetShield extension) is the same message within iOS's limits.
struct ShieldPreviewView: View {
    var item: NapItem
    var onBack: () -> Void
    @Environment(LockEngine.self) private var engine

    var body: some View {
        ScreenFrame(resting: true) {
            Spacer()
            AppTile(item: item, size: 72, radius: Theme.Radius.shieldTile, showsName: false)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.shieldTile, style: .continuous)
                        .fill(Theme.ink).offset(y: Theme.Shadow.l)
                )
                .padding(.bottom, Theme.Shadow.l)
            StatusLine(text: "// \(statusKey).status = resting")
            headline
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = engine.restingSince.map { context.date.timeIntervalSince($0) } ?? 0
                BodyText(text: "Reset for \(DurationFormat.clock(elapsed)). Tap your phone on the puck to wake it.")
            }
            Spacer()
            Button("Back to home", action: onBack)
                .buttonStyle(.secondary)
        }
    }

    /// Real apps never reveal their name to reset outside Apple's `Label`, so the
    /// status key falls back to "app".
    private var statusKey: String {
        if case .demo(let app) = item { return app.name.lowercased() }
        return "app"
    }

    @ViewBuilder private var headline: some View {
        switch item {
        case .demo(let app):
            Headline(text: "Shh. \(app.name) is napping.", size: 48)
        case .app(let token):
            HStack(spacing: 0) {
                Text("Shh. ")
                Label(token).labelStyle(.titleOnly)
                Text(" is napping.")
            }
            .font(RFont.display(48))
        default:
            Headline(text: "Shh. It's napping.", size: 48)
        }
    }
}
