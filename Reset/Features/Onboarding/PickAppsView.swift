import FamilyControls
import SwiftUI

/// 3. Pick apps (02 / 02). Also reused from Settings to change the apps.
///
/// iOS never lists installed apps, so the real build opens Apple's picker and shows the
/// result. The demo build shows the prototype's toggle list.
struct PickAppsView: View {
    var isOnboarding = true
    var onDone: (() -> Void)?

    @Environment(LockEngine.self) private var engine
    @Environment(AppEnvironment.self) private var environment
    @State private var draft = NapSelection()
    @State private var showingPicker = false

    var body: some View {
        ScreenFrame(spacing: 12) {
            HStack {
                MonoLink(title: "← back") {
                    if isOnboarding { engine.startPairing() } else { onDone?() }
                }
                Spacer()
                if isOnboarding { Text("02 / 03").font(RFont.label).foregroundStyle(Theme.subtle) }
            }
            .padding(.horizontal, 4)
            Headline(text: "What should nap?")
                .padding(.top, 10)
                .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 0) {
                    if environment.isDemo {
                        ForEach(DemoApp.all) { app in
                            Toggle(isOn: demoBinding(app)) { row(.demo(app)) }
                                .toggleStyle(InkToggleStyle())
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .overlay(alignment: .bottom) { DashedDivider() }
                        }
                    } else {
                        ForEach(draft.items) { item in
                            row(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .overlay(alignment: .bottom) { DashedDivider() }
                        }
                        Button(draft.isEmpty ? "Choose apps" : "Change apps") { showingPicker = true }
                            .font(RFont.body(15, .semibold))
                            .foregroundStyle(engine.casing.ink.color)
                            .padding(16)
                    }
                }
            }
            .inkCard(radius: Theme.Radius.cardL)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cardL, style: .continuous))

            Button(buttonTitle) {
                engine.saveSelection(draft)
                onDone?()
            }
            .buttonStyle(.primary)
            .disabled(draft.isEmpty)
        }
        .padding(.horizontal, -2)
        .familyActivityPicker(isPresented: $showingPicker, selection: $draft.family)
        .task {
            draft = engine.selection
            if environment.isDemo, draft.isEmpty { draft.demoApps = DemoApp.defaults }
            if !engine.isAuthorized { await engine.requestAuthorization() }
        }
    }

    private var buttonTitle: String {
        let n = draft.count
        if n == 0 { return "Pick at least one" }
        return isOnboarding ? "Rest \(n) app\(n == 1 ? "" : "s")" : "Save"
    }

    private func row(_ item: NapItem) -> some View {
        HStack(spacing: 12) {
            AppTile(item: item, size: 36, radius: Theme.Radius.tileS, showsName: false)
            Group {
                switch item {
                case .demo(let app): Text(app.name)
                case .app(let token): Label(token).labelStyle(.titleOnly)
                case .category(let token): Label(token).labelStyle(.titleOnly)
                case .web(let token): Label(token).labelStyle(.titleOnly)
                }
            }
            .font(RFont.body(15, .medium))
        }
    }

    private func demoBinding(_ app: DemoApp) -> Binding<Bool> {
        Binding {
            draft.demoApps.contains(app)
        } set: { on in
            if on {
                draft.demoApps = DemoApp.all.filter { draft.demoApps.contains($0) || $0 == app }
            } else {
                draft.demoApps.removeAll { $0 == app }
            }
        }
    }
}

struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}
