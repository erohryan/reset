import SwiftUI

/// 5. Locked ("resting"). Soft background, live timer, napping tiles.
struct RestingView: View {
    @Environment(LockEngine.self) private var engine
    @State private var peek: NapItem?
    @State private var showingEmergency = false

    var body: some View {
        let napping = engine.nappingSelection
        ScreenFrame(resting: true) {
            HStack {
                Wordmark()
                Spacer()
                StatusLine(text: "// resting", size: 11)
            }

            Button {
                Task { await engine.puckTap() }
            } label: {
                PuckView(label: "zzz", resting: true, reading: engine.isReading)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)

            VStack(spacing: 6) {
                StatusLine(text: engine.notice ?? (engine.isReading ? "waking everything…" : "\(napping.count) apps napping"))
                Headline(text: "You're reset.", size: 42)
                RestTimer(since: engine.restingSince)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            Spacer(minLength: 0)
            AppGrid(items: napping.items, napping: true, onTap: { peek = $0 })

            VStack(spacing: 8) {
                Text("tap an app to peek · tap the puck to wake")
                // Emergency wake lives outside the main flow, deliberately quiet.
                Button("lost your puck?") { showingEmergency = true }
                    .buttonStyle(.plain)
                    .underline()
            }
            .font(RFont.caption)
            .foregroundStyle(Theme.subtle)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .fullScreenCover(item: $peek) { item in
            ShieldPreviewView(item: item) { peek = nil }
                .environment(\.casing, engine.casing)
        }
        .sheet(isPresented: $showingEmergency) {
            EmergencyWakeSheet()
                .presentationDetents([.medium])
        }
    }
}

/// HH:MM:SS, ticking every second.
struct RestTimer: View {
    var since: Date?
    var font: Font = RFont.timerM

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(DurationFormat.clock(since.map { context.date.timeIntervalSince($0) } ?? 0))
                .font(font)
                .monospacedDigit()
        }
    }
}
