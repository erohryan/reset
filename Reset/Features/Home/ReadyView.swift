import SwiftUI

/// 4. Ready (home). Tap the puck to rest the chosen apps.
struct ReadyView: View {
    @Environment(LockEngine.self) private var engine
    @State private var showingSettings = false

    var body: some View {
        let count = engine.activeSelection.count
        ScreenFrame {
            HStack {
                Wordmark()
                Spacer()
                MonoChip(text: "\(engine.streak()) days")
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .inkSurface(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            Button {
                Task { await engine.puckTap() }
            } label: {
                PuckView(label: "tap", reading: engine.isReading)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)

            VStack(spacing: 6) {
                StatusLine(text: engine.notice ?? (engine.isReading ? "reading puck…" : count == 0 ? "// every app is switched off" : "// puck nearby"))
                Headline(text: "Ready when you are.", size: 38)
                BodyText(text: "Hold your phone to the puck to rest \(count) app\(count == 1 ? "" : "s").", size: 14)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            Spacer(minLength: 0)
            // Quick settings: tap a tile to keep that app awake next time. Most-rested first.
            AppGrid(items: engine.quickToggleItems(), isOff: engine.isSkipped, onTap: { engine.toggleSkipped($0) })
            Text("tap an app to keep it awake next time")
                .font(RFont.caption)
                .foregroundStyle(Theme.subtle)
                .frame(maxWidth: .infinity)
            PillStat(
                value: "\(DurationFormat.short(engine.restedToday())) today",
                caption: "avg \(DurationFormat.short(engine.dailyAverage()))"
            )
            .padding(.top, 6)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
