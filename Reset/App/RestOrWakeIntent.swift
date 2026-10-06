import AppIntents

/// "Rest or wake": what a puck's Shortcuts NFC automation runs, so a tap toggles reset
/// without opening the app. Returns "resting" or "awake" so the automation can switch
/// a Focus on or off to match.
struct RestOrWakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Rest or wake"
    static let description = IntentDescription(
        "Rests your chosen apps, or wakes them if they're napping. Add it to an NFC automation for your puck."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let resting = try AppEnvironment.shared.engine.toggleFromShortcut()
        return .result(value: resting ? "resting" : "awake")
    }
}

struct ResetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RestOrWakeIntent(),
            phrases: ["Rest or wake with \(.applicationName)", "\(.applicationName) rest or wake"],
            shortTitle: "Rest or wake",
            systemImageName: "moon.zzz"
        )
    }
}
