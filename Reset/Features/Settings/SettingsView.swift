import SwiftUI

/// Settings: pucks (name, colour, tap-only, forget), apps, emergency wakes and erase.
/// Reached from the Ready header.
struct SettingsView: View {
    @Environment(LockEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var editingApps = false
    @State private var confirmingErase = false

    var body: some View {
        ScreenFrame {
            HStack {
                Headline(text: "Settings", size: 40)
                Spacer()
                MonoLink(title: "done") { dismiss() }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    section("// pucks · \(engine.pucks.count)") {
                        BodyText(text: "Any of your pucks can rest or wake your apps. A puck can be shared with other phones too.", size: 13)
                        ForEach(engine.pucks) { puck in
                            PuckRow(puck: puck) { dismiss() }
                            DashedDivider()
                        }
                        Button("Pair another puck") {
                            dismiss()
                            engine.startPairing()
                        }
                        .buttonStyle(.secondary)
                    }

                    section("// apps") {
                        HStack {
                            Text("\(engine.selection.count) apps chosen").font(RFont.body(15))
                            Spacer()
                            Button("change") { editingApps = true }
                                .font(RFont.label)
                                .foregroundStyle(engine.casing.ink.color)
                        }
                    }

                    section("// emergency wakes") {
                        BodyText(text: "\(engine.emergencyRemaining) of \(KeychainEmergencyAllowance.total) left. Use one from the resting screen if you can't reach a puck.", size: 14)
                    }

                    if confirmingErase {
                        VStack(spacing: 8) {
                            BodyText(text: "This forgets every puck, your apps and your streak.", size: 14)
                            Button("Yes, erase everything") {
                                engine.eraseEverything()
                                dismiss()
                            }
                            .buttonStyle(.secondary)
                            MonoLink(title: "keep everything") { confirmingErase = false }
                        }
                    } else {
                        MonoLink(title: "erase everything") { confirmingErase = true }
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .environment(\.casing, engine.casing)
        .fullScreenCover(isPresented: $editingApps) {
            PickAppsView(isOnboarding: false) { editingApps = false }
                .environment(\.casing, engine.casing)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusLine(text: title, size: 11)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkCard()
    }
}

/// One puck: name, colour, tap-only status, forget.
private struct PuckRow: View {
    var puck: Puck
    var onLeaveSettings: () -> Void
    @Environment(LockEngine.self) private var engine
    @State private var expanded = false
    @State private var confirmingForget = false

    private var canForget: Bool { engine.restingSince == nil || engine.pucks.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(puck.casing.accent.color)
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.border))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(puck.name).font(RFont.body(15, .semibold))
                        Text("\(puck.displayID) · \(puck.tapOnlyReady ? "tap-only ✓" : "in-app tap")")
                            .font(RFont.caption)
                            .foregroundStyle(Theme.subtle)
                    }
                    Spacer()
                    Text(expanded ? "–" : "+").font(RFont.label)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                PuckNameField(name: Binding(get: { puck.name }, set: { engine.renamePuck(puck.id, to: $0) }))
                CasingPicker(selection: Binding(get: { puck.casing }, set: { engine.changeCasing($0, for: puck.id) }))
                HStack {
                    Button(puck.tapOnlyReady ? "redo tap-only setup" : "set up tap-only") {
                        onLeaveSettings()
                        engine.showTapSetup(for: puck.id)
                    }
                    .foregroundStyle(engine.casing.ink.color)
                    Spacer()
                    if canForget {
                        Button(confirmingForget ? "tap again to forget" : "forget") {
                            if confirmingForget { engine.removePuck(puck.id) } else { confirmingForget = true }
                        }
                        .foregroundStyle(Theme.subtle)
                    }
                }
                .font(RFont.label)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Confirms an emergency wake and shows how many are left.
struct EmergencyWakeSheet: View {
    @Environment(LockEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let left = engine.emergencyRemaining
        ScreenFrame(resting: true) {
            StatusLine(text: "// emergency wake")
            Headline(text: left > 0 ? "Can't reach a puck?" : "No emergency wakes left.", size: 34)
            BodyText(text: left > 0
                ? "You have \(left) of \(KeychainEmergencyAllowance.total) emergency wakes. They don't come back, and this rest won't count toward your streak."
                : "Tap your phone on any of your pucks to wake your apps.", size: 14)
            Spacer(minLength: 0)
            if left > 0 {
                Button("Wake apps now") {
                    engine.emergencyWake()
                    dismiss()
                }
                .buttonStyle(.secondary)
            }
            MonoLink(title: "keep resting") { dismiss() }
                .frame(maxWidth: .infinity)
        }
        .environment(\.casing, engine.casing)
    }
}
