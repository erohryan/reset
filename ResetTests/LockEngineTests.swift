import XCTest
@testable import ResetDemo

@MainActor
final class LockEngineTests: XCTestCase {
    private var reader: MockTagReader!
    private var blocking: MockBlockingService!
    private var store: InMemoryStateStore!
    private var puckStore: InMemoryPuckStore!
    private var emergency: InMemoryEmergencyAllowance!
    private var clock: Date!
    private var calendar: Calendar!

    private let homeUID = Data([0x04, 0xF2, 0x1A, 0x9C, 0x33, 0x80, 0x01])
    private let deskUID = Data([0x04, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x02])

    override func setUp() {
        reader = MockTagReader(uid: homeUID, delay: .zero)
        blocking = MockBlockingService()
        store = InMemoryStateStore()
        puckStore = InMemoryPuckStore()
        emergency = InMemoryEmergencyAllowance()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = Date(timeIntervalSince1970: 1_790_000_000) // a fixed afternoon
    }

    private func makeEngine() -> LockEngine {
        LockEngine(reader: reader, blocking: blocking, store: store, puckStore: puckStore, emergency: emergency, calendar: calendar) { [unowned self] in clock }
    }

    private func pair(_ engine: LockEngine) async {
        engine.startPairing()
        await engine.pairTap()
        engine.confirmPuck()
    }

    /// Pairs the home tag and saves a demo selection, leaving the engine on Ready.
    private func readyEngine() async -> LockEngine {
        let engine = makeEngine()
        await pair(engine)
        engine.saveSelection(NapSelection(demoApps: DemoApp.defaults))
        engine.finishTapSetup(done: false)
        return engine
    }

    // MARK: Pairing

    func testStartsOnWelcomeWithNoPuck() {
        XCTAssertEqual(makeEngine().route, .welcome)
    }

    func testFirstPairingGoesPairPickTapSetupReady() async {
        let engine = makeEngine()
        engine.startPairing()
        await engine.pairTap()
        guard case .found(let puck, let isNew) = engine.pairStatus else { return XCTFail("puck not found") }
        XCTAssertTrue(isNew)
        XCTAssertEqual(puck.casing, .clay)
        XCTAssertNotNil(reader.storedPayload)

        engine.confirmPuck()
        XCTAssertEqual(engine.route, .pick)
        engine.saveSelection(NapSelection(demoApps: DemoApp.defaults))
        XCTAssertEqual(engine.route, .tapSetup)
        XCTAssertEqual(engine.tapSetupPuck?.id, puck.id)
        engine.finishTapSetup(done: true)
        XCTAssertEqual(engine.route, .ready)
        XCTAssertTrue(engine.pucks[0].tapOnlyReady)
    }

    func testPucksAreRememberedInPuckStore() async {
        _ = await readyEngine()
        XCTAssertEqual(puckStore.pucks.count, 1)
        // A reinstall wipes the state file but not the Keychain.
        store = InMemoryStateStore()
        let reinstalled = makeEngine()
        XCTAssertEqual(reinstalled.pucks.count, 1)
        XCTAssertEqual(reinstalled.route, .pick)
    }

    func testPairingKeepsSecretAndHueAlreadyOnTag() async {
        // A puck already paired to another phone: same secret, so both phones trust it.
        let shared = PuckPayload(secret: Data(repeating: 9, count: 16), hue: 155)
        reader.storedPayload = shared
        let engine = makeEngine()
        engine.startPairing()
        await engine.pairTap()
        guard case .found(let puck, _) = engine.pairStatus else { return XCTFail("puck not found") }
        XCTAssertEqual(puck.casing, .sage)
        XCTAssertEqual(reader.storedPayload, shared)
        XCTAssertEqual(puck.tagHash, PuckVerifier.hash(uid: homeUID, secret: shared.secret))
    }

    func testTwoPhonesCanShareOnePuck() async {
        let phoneA = await readyEngine()
        // Phone B has its own storage but pairs the same physical tag.
        store = InMemoryStateStore()
        puckStore = InMemoryPuckStore()
        let phoneB = await readyEngine()

        await phoneB.puckTap()
        XCTAssertEqual(phoneB.route, .resting)
        await phoneA.puckTap()
        XCTAssertEqual(phoneA.route, .resting, "phone A still trusts the puck after phone B paired it")
    }

    func testRepairingSamePuckDoesNotDuplicate() async {
        let engine = await readyEngine()
        engine.startPairing()
        await engine.pairTap()
        guard case .found(_, let isNew) = engine.pairStatus else { return XCTFail("puck not found") }
        XCTAssertFalse(isNew)
        engine.confirmPuck()
        XCTAssertEqual(engine.pucks.count, 1)
    }

    func testRestWithOnePuckWakeWithAnother() async {
        // Two tags, each with its own secret, both paired.
        let engine = await readyEngine()
        let homePayload = reader.storedPayload
        reader.uid = deskUID
        reader.storedPayload = nil
        await pair(engine)
        engine.finishTapSetup(done: false)
        let deskPayload = reader.storedPayload

        await engine.puckTap()
        XCTAssertEqual(engine.route, .resting)
        XCTAssertEqual(engine.themePuck?.name, "Puck 2")

        reader.uid = homeUID
        reader.storedPayload = homePayload
        clock += 600
        await engine.puckTap()
        XCTAssertEqual(engine.route, .wake)
        XCTAssertEqual(engine.themePuck?.name, "Home", "the last puck tapped themes the app")
        XCTAssertNotNil(deskPayload)
    }

    func testRemovingLastPuckIsBlockedWhileResting() async {
        let engine = await readyEngine()
        await engine.puckTap()
        engine.removePuck(engine.pucks[0].id)
        XCTAssertEqual(engine.pucks.count, 1)
    }

    // MARK: Rest and wake

    func testTapRestsThenTapWakes() async {
        let engine = await readyEngine()
        await engine.puckTap()
        XCTAssertEqual(engine.route, .resting)
        XCTAssertEqual(blocking.resting?.count, 6)

        clock += 754
        await engine.puckTap()
        XCTAssertEqual(engine.route, .wake)
        XCTAssertNil(blocking.resting)
        XCTAssertEqual(engine.lastRest?.duration, 754)

        engine.finishWake()
        XCTAssertEqual(engine.route, .ready)
    }

    func testUnknownTagIsRejected() async {
        let engine = await readyEngine()
        reader.uid = Data([0xDE, 0xAD])
        reader.storedPayload = PuckPayload(secret: Data([9]))
        await engine.puckTap()
        XCTAssertEqual(engine.route, .ready)
        XCTAssertEqual(engine.notice, "// not your puck")
        XCTAssertNil(blocking.resting)
    }

    func testClonedUIDWithoutSecretIsRejected() async {
        let engine = await readyEngine()
        await engine.puckTap()
        reader.storedPayload = nil // same UID, secret wiped
        await engine.puckTap()
        XCTAssertEqual(engine.route, .resting)
        XCTAssertNotNil(blocking.resting)
    }

    func testCancelledReadShowsNoNotice() async {
        let engine = await readyEngine()
        reader.nextError = .cancelled
        await engine.puckTap()
        XCTAssertNil(engine.notice)
        XCTAssertEqual(engine.route, .ready)
    }

    func testShortcutTogglesWithoutAnInAppTap() async throws {
        let engine = await readyEngine()
        XCTAssertTrue(try engine.toggleFromShortcut())
        XCTAssertEqual(engine.route, .resting)
        XCTAssertNotNil(blocking.resting)
        clock += 60
        XCTAssertFalse(try engine.toggleFromShortcut())
        XCTAssertEqual(engine.route, .wake)
        XCTAssertNil(blocking.resting)
    }

    func testShortcutFailsBeforeSetup() {
        XCTAssertThrowsError(try makeEngine().toggleFromShortcut())
    }

    func testEmergencyWakeIsLimitedAndSkipsStreak() async {
        emergency = InMemoryEmergencyAllowance(remaining: 1)
        let engine = await readyEngine()
        await engine.puckTap()

        XCTAssertTrue(engine.emergencyWake())
        XCTAssertEqual(engine.route, .wake)
        XCTAssertEqual(engine.lastRest?.emergency, true)
        XCTAssertEqual(engine.streak(), 0)

        engine.finishWake()
        await engine.puckTap()
        XCTAssertFalse(engine.emergencyWake())
        XCTAssertEqual(engine.route, .resting)
    }

    func testRestingStateSurvivesRelaunch() async {
        let engine = await readyEngine()
        await engine.puckTap()
        let relaunched = makeEngine()
        XCTAssertEqual(relaunched.route, .resting)
        XCTAssertNotNil(relaunched.restingSince)
    }

    // MARK: Quick toggles

    func testSkippedAppsStayAwake() async {
        let engine = await readyEngine()
        let tiktok = NapItem.demo(DemoApp.all[1])
        engine.toggleSkipped(tiktok)
        XCTAssertTrue(engine.isSkipped(tiktok))
        XCTAssertEqual(engine.activeSelection.count, 5)

        await engine.puckTap()
        XCTAssertEqual(blocking.resting?.count, 5)
        XCTAssertFalse(blocking.resting!.contains(tiktok))
        XCTAssertEqual(engine.nappingSelection.count, 5)

        engine.toggleSkipped(tiktok) // ignored while resting
        XCTAssertTrue(engine.isSkipped(tiktok))
    }

    func testCantRestWithEveryAppSwitchedOff() async {
        let engine = await readyEngine()
        engine.selection.items.forEach(engine.toggleSkipped)
        await engine.puckTap()
        XCTAssertEqual(engine.route, .ready)
        XCTAssertEqual(engine.notice, "// every app is switched off")
    }

    func testQuickTogglesSortByHowOftenYouRestThem() async {
        let engine = await readyEngine()
        let youtube = NapItem.demo(DemoApp.all[3])
        // Rest twice with only YouTube on, once with everything.
        for item in engine.selection.items where item != youtube { engine.toggleSkipped(item) }
        for _ in 0..<2 {
            await engine.puckTap(); await engine.puckTap(); engine.finishWake()
        }
        for item in engine.selection.items where item != youtube { engine.toggleSkipped(item) }
        await engine.puckTap(); await engine.puckTap(); engine.finishWake()

        let order = engine.quickToggleItems()
        XCTAssertEqual(order.first, youtube)
        XCTAssertEqual(Array(order.dropFirst()), engine.selection.items.filter { $0 != youtube }, "ties keep the chosen order")
    }

    func testChangingAppsDropsStaleSkips() async {
        let engine = await readyEngine()
        engine.toggleSkipped(.demo(DemoApp.all[5]))
        engine.saveSelection(NapSelection(demoApps: Array(DemoApp.all.prefix(3))))
        XCTAssertTrue(engine.state.skipped.isEmpty)
    }

    // MARK: Stats

    func testStreakCountsConsecutiveDays() async {
        let engine = await readyEngine()
        for _ in 0..<3 {
            await engine.puckTap()
            clock += 600
            await engine.puckTap()
            engine.finishWake()
            clock += 86_400
        }
        // Today has no rest yet, so the streak runs through yesterday.
        XCTAssertEqual(engine.streak(), 3)
        clock += 86_400 // skip a day
        XCTAssertEqual(engine.streak(), 0)
    }

    func testRestedTodayIncludesCurrentRest() async {
        let engine = await readyEngine()
        await engine.puckTap()
        clock += 1_800
        XCTAssertEqual(engine.restedToday(), 1_800)
    }

    func testEraseIsBlockedWhileResting() async {
        let engine = await readyEngine()
        await engine.puckTap()
        engine.eraseEverything()
        XCTAssertEqual(engine.route, .resting)
        XCTAssertFalse(store.state.pucks.isEmpty)
    }
}
