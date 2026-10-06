import SwiftUI

/// 2. Pair puck (01 / 02). Tapping the on-screen puck starts the NFC read.
/// Also used to add more pucks later (one per location).
struct PairView: View {
    @Environment(LockEngine.self) private var engine

    private var found: (puck: Puck, isNew: Bool)? {
        if case .found(let puck, let isNew) = engine.pairStatus { return (puck, isNew) }
        return nil
    }

    private var isFirstPuck: Bool { engine.pucks.isEmpty }

    private var status: String {
        if let notice = engine.notice, engine.pairStatus == .idle { return notice }
        switch engine.pairStatus {
        case .idle: return "waiting for a tap"
        case .reading: return "reading puck…"
        case .found(_, let isNew): return isNew ? "found it ✓" : "already paired ✓"
        }
    }

    var body: some View {
        ScreenFrame(spacing: 12) {
            HStack {
                MonoLink(title: "← back") { engine.cancelPairing() }
                Spacer()
                Text(isFirstPuck ? "01 / 03" : "new puck").font(RFont.label).foregroundStyle(Theme.subtle)
            }
            Headline(text: "Hold your phone to the puck.").padding(.top, 10)
            BodyText(text: isFirstPuck
                ? "The top of the phone works best."
                : "Add a puck for another room. Any of your pucks can rest or wake your apps.", size: 14)

            VStack(spacing: 18) {
                Button {
                    Task { await engine.pairTap() }
                } label: {
                    PuckView(label: found == nil ? "tap" : "hello", reading: engine.isReading, casingOverride: found?.puck.casing)
                }
                .buttonStyle(.plain)
                .disabled(found != nil)
                StatusLine(text: status)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let found {
                PuckCard(puck: found.puck, isNew: found.isNew)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }

            Button(found?.isNew == false ? "Save" : "Continue") { engine.confirmPuck() }
                .buttonStyle(.primary)
                .disabled(found == nil)
        }
        .environment(\.casing, found?.puck.casing ?? engine.casing)
        .animation(.easeOut(duration: 0.3), value: found?.puck)
    }
}

/// "Your puck, Clay · id rs-04f2 · nfc ok", with a name and casing swatches.
private struct PuckCard: View {
    var puck: Puck
    var isNew: Bool
    @Environment(LockEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(puck.casing.accent.color)
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.border))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(isNew ? "Your puck, \(puck.casing.name)" : "Already paired: \(puck.name)")
                        .font(RFont.body(14, .semibold))
                    Text("id \(puck.displayID) · nfc ok").font(RFont.caption).foregroundStyle(Theme.subtle)
                }
            }
            PuckNameField(name: Binding(get: { puck.name }, set: { engine.editFoundPuck(name: $0) }))
            CasingPicker(selection: Binding(get: { puck.casing }, set: { engine.editFoundPuck(casing: $0) }))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .inkCard()
    }
}

/// "where does it live?" field plus quick picks.
struct PuckNameField: View {
    @Binding var name: String
    private let suggestions = ["Home", "Desk", "Bedside", "Kitchen", "Car"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("where does it live?", text: $name)
                .font(RFont.body(15, .medium))
                .textInputAutocapitalization(.words)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .inkSurface(RoundedRectangle(cornerRadius: 12, style: .continuous))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion.lowercased()) { name = suggestion }
                            .font(RFont.caption)
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .inkSurface(Capsule(), stroke: name == suggestion ? Theme.ink : Theme.divider)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}
