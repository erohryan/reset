import Foundation
import Observation

/// Wires the engine to real or mock services.
///
/// `ResetDemo` (compiled with RESET_DEMO) uses mock NFC and mock blocking so it can be
/// signed with a free Apple ID and run in the Simulator. `Reset` uses Core NFC and Screen Time.
@MainActor
@Observable
final class AppEnvironment {
    let engine: LockEngine
    let isDemo: Bool

    init(engine: LockEngine, isDemo: Bool) {
        self.engine = engine
        self.isDemo = isDemo
    }

    /// One engine per process, shared by the UI and the "Rest or wake" App Intent.
    static let shared = AppEnvironment.live()

    static func live() -> AppEnvironment {
        #if RESET_DEMO
        let isDemo = true
        #else
        // The Simulator has no NFC or Screen Time, so the full target falls back to mocks there too.
        let isDemo = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif

        let store = FileStateStore()
        let mockReader = MockTagReader()
        mockReader.newTagEachPair = true
        #if DEBUG
        // Launch with `-seed ready|skipped|resting` to jump straight to a screen while designing.
        if isDemo, let seed = UserDefaults.standard.string(forKey: "seed") {
            let seeded = DemoSeed.state(seed, puck: mockReader)
            store.save(seeded)
            KeychainPuckStore().save(seeded.pucks)
        }
        #endif

        #if RESET_DEMO
        let reader: TagReader = mockReader
        let blocking: BlockingService = MockBlockingService()
        #else
        let reader: TagReader = isDemo ? mockReader : CoreNFCTagReader()
        let blocking: BlockingService = isDemo ? MockBlockingService() : ScreenTimeBlockingService()
        #endif

        let engine = LockEngine(
            reader: reader,
            blocking: blocking,
            store: store,
            puckStore: KeychainPuckStore(),
            emergency: KeychainEmergencyAllowance(),
            shared: SharedState()
        )
        #if DEBUG
        // `-screen tapsetup` opens the tap-only guide for the first puck.
        if isDemo, UserDefaults.standard.string(forKey: "screen") == "tapsetup", !engine.pucks.isEmpty {
            engine.showTapSetup()
        }
        #endif
        return AppEnvironment(engine: engine, isDemo: isDemo)
    }
}

#if DEBUG
/// Sample data for the demo build: a Clay puck, the prototype's six apps and a week of rests.
enum DemoSeed {
    /// Also writes the seeded payload onto `mock`, so tapping the on-screen puck works.
    static func state(_ seed: String, puck mock: MockTagReader) -> ResetState {
        let secret = Data(repeating: 7, count: 16)
        mock.storedPayload = PuckPayload(secret: secret, hue: 45)
        let puck = Puck(name: "Home", tagHash: PuckVerifier.hash(uid: mock.uid, secret: secret), casing: .clay, pairedAt: .now)
        let desk = Puck(name: "Desk", tagHash: "d35c" + String(repeating: "0", count: 60), casing: .sage, pairedAt: .now)

        var state = ResetState()
        state.pucks = [puck, desk]
        state.selection = NapSelection(demoApps: DemoApp.defaults)
        let rested = NapSelection(demoApps: [DemoApp.all[1], DemoApp.all[0], DemoApp.all[3]])
        let today = Calendar.current.startOfDay(for: .now)
        for day in 1...12 {
            let start = Calendar.current.date(byAdding: .day, value: -day, to: today)!.addingTimeInterval(9 * 3600)
            state.sessions.append(RestSession(puckID: puck.id, startedAt: start, endedAt: start.addingTimeInterval(Double(7_000 + day * 400)), rested: rested))
        }
        if seed == "skipped" {
            state.skipped = NapSelection(demoApps: [DemoApp.all[4]])
        }
        if seed == "resting" {
            state.sessions.append(RestSession(puckID: puck.id, startedAt: .now.addingTimeInterval(-754), rested: state.selection))
        }
        return state
    }
}
#endif
