import Foundation
import Observation

/// The screens in the main flow (design README, "Interactions and state").
/// Shield preview and settings are presented over these, so they aren't routes.
enum Route: Equatable {
    case welcome, pair, pick, tapSetup, ready, resting, wake
}

enum PairStatus: Equatable {
    case idle, reading
    /// `isNew` is false when this tag was already paired to this device.
    case found(Puck, isNew: Bool)
}

enum ToggleError: LocalizedError {
    case notSetUp
    case nothingToRest

    var errorDescription: String? {
        switch self {
        case .notSetUp: "Open reset to pair a puck and choose apps first."
        case .nothingToRest: "Every app is switched off in reset. Turn one on first."
        }
    }
}

/// Owns reset's state and the rules for resting and waking apps. Every screen reads
/// from it; NFC, blocking and storage are injected so it runs on mocks in tests.
@MainActor
@Observable
final class LockEngine {
    private(set) var state: ResetState
    private(set) var route: Route
    private(set) var pairStatus: PairStatus = .idle
    /// An NFC read is in progress. Repeat taps are ignored.
    private(set) var isReading = false
    /// A short status message shown in place of the usual `// status` line, e.g. a wrong puck.
    private(set) var notice: String?
    /// The rest that just ended, shown on the wake screen.
    private(set) var lastRest: RestSession?
    /// The puck the tap-only setup screen is for.
    private(set) var tapSetupPuckID: UUID?
    /// Where the tap-only setup screen goes when it's done.
    private var tapSetupReturn: Route = .ready

    private let reader: TagReader
    private let blocking: BlockingService
    private let store: StateStore
    private let puckStore: PuckStore
    private let shared: SharedState?
    private let emergency: EmergencyAllowance
    private let now: () -> Date
    private let calendar: Calendar

    init(
        reader: TagReader,
        blocking: BlockingService,
        store: StateStore,
        puckStore: PuckStore,
        emergency: EmergencyAllowance,
        shared: SharedState? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.reader = reader
        self.blocking = blocking
        self.store = store
        self.puckStore = puckStore
        self.emergency = emergency
        self.shared = shared
        self.calendar = calendar
        self.now = now

        let loaded = Self.merged(store.load(), pucks: puckStore.load())
        state = loaded
        route = Self.startRoute(for: loaded)
    }

    /// The Keychain is the source of truth for pucks; the state file keeps a copy.
    private static func merged(_ state: ResetState, pucks: [Puck]) -> ResetState {
        var state = state
        if !pucks.isEmpty { state.pucks = pucks }
        return state
    }

    private static func startRoute(for state: ResetState) -> Route {
        if state.pucks.isEmpty { return .welcome }
        if state.selection.isEmpty { return .pick }
        return state.activeSession == nil ? .ready : .resting
    }

    /// Picks up changes made while the app was in the background (the Shortcuts
    /// automation, iCloud Keychain sync).
    func reload() {
        let fresh = Self.merged(store.load(), pucks: puckStore.load())
        guard fresh != state else { return }
        let wasResting = state.activeSession != nil
        state = fresh
        switch route {
        case .ready, .resting:
            route = Self.startRoute(for: fresh)
        case .wake where fresh.activeSession != nil:
            route = .resting
        default:
            break
        }
        if wasResting, fresh.activeSession == nil, route == .resting { route = .ready }
    }

    // MARK: Derived state

    var pucks: [Puck] { state.pucks }
    var themePuck: Puck? { state.pucks.first { $0.id == state.themePuckID } ?? state.pucks.first }
    var casing: Casing { themePuck?.casing ?? .default }
    var selection: NapSelection { state.selection }
    /// What the next rest will nap: chosen apps minus the ones switched off on the home screen.
    var activeSelection: NapSelection { state.selection.subtracting(state.skipped) }
    var restingSince: Date? { state.activeSession?.startedAt }
    /// What's napping right now (or would nap next, when awake).
    var nappingSelection: NapSelection { state.activeSession?.rested ?? activeSelection }
    var emergencyRemaining: Int { emergency.remaining }
    var isAuthorized: Bool { blocking.isAuthorized }

    // MARK: Pairing

    func startPairing() {
        pairStatus = .idle
        notice = nil
        route = .pair
    }

    func back(to route: Route) {
        self.route = route
    }

    /// "← back" from pairing: home if you already have a puck, else the welcome screen.
    func cancelPairing() {
        pairStatus = .idle
        route = state.pucks.isEmpty ? .welcome : Self.startRoute(for: state)
    }

    /// Reads a tag. A tag already carrying a reset secret keeps it, so one puck can be
    /// shared by several phones; a blank tag gets a fresh secret.
    func pairTap() async {
        guard !isReading, pairStatus == .idle else { return }
        isReading = true
        pairStatus = .reading
        notice = nil
        defer { isReading = false }

        let fresh = PuckPayload.makeSecret()
        var written: PuckPayload?
        do {
            let read = try await reader.pair { existing in
                let payload = PuckPayload(secret: existing?.secret ?? fresh, hue: existing?.hue)
                written = payload
                return payload
            }
            guard let payload = written else { throw TagReaderError.notAPuck }
            let hash = PuckVerifier.hash(uid: read.uid, secret: payload.secret)

            if let known = state.pucks.first(where: { $0.tagHash == hash }) {
                pairStatus = .found(known, isNew: false)
            } else {
                let casing = payload.hue.map(Casing.forHue) ?? .default
                let name = state.pucks.isEmpty ? "Home" : "Puck \(state.pucks.count + 1)"
                pairStatus = .found(Puck(name: name, tagHash: hash, casing: casing, pairedAt: now()), isNew: true)
            }
        } catch {
            pairStatus = .idle
            show(error)
        }
    }

    func editFoundPuck(name: String? = nil, casing: Casing? = nil) {
        guard case .found(var puck, let isNew) = pairStatus else { return }
        if let name { puck.name = name }
        if let casing { puck.casing = casing }
        pairStatus = .found(puck, isNew: isNew)
    }

    /// Saves the found puck (adding it, or updating a known one) and moves on.
    func confirmPuck() {
        guard case .found(let puck, _) = pairStatus else { return }
        if let index = state.pucks.firstIndex(where: { $0.id == puck.id }) {
            state.pucks[index] = puck
        } else {
            state.pucks.append(puck)
        }
        state.themePuckID = puck.id
        persist()
        pairStatus = .idle

        if state.selection.isEmpty {
            route = .pick
        } else {
            showTapSetup(for: puck.id)
        }
    }

    func renamePuck(_ id: UUID, to name: String) {
        updatePuck(id) { $0.name = name }
    }

    func changeCasing(_ casing: Casing, for id: UUID) {
        updatePuck(id) { $0.casing = casing }
    }

    func markTapOnlyReady(_ id: UUID, _ ready: Bool = true) {
        updatePuck(id) { $0.tapOnlyReady = ready }
    }

    /// Forgets a puck. The last puck can't be removed while apps are napping.
    func removePuck(_ id: UUID) {
        guard state.activeSession == nil || state.pucks.count > 1 else { return }
        state.pucks.removeAll { $0.id == id }
        if state.themePuckID == id { state.themePuckID = state.pucks.first?.id }
        persist()
        if state.pucks.isEmpty { route = .welcome }
    }

    private func updatePuck(_ id: UUID, _ change: (inout Puck) -> Void) {
        guard let index = state.pucks.firstIndex(where: { $0.id == id }) else { return }
        change(&state.pucks[index])
        persist()
    }

    // MARK: Apps

    func requestAuthorization() async {
        do { try await blocking.requestAuthorization() } catch { show(error) }
    }

    func saveSelection(_ selection: NapSelection) {
        guard !selection.isEmpty else { return }
        state.selection = selection
        state.skipped = state.skipped.intersecting(selection)
        persist()
        if route == .pick { showTapSetup(returningTo: .ready) }
    }

    /// Quick toggle on the home screen: keep an app awake on the next rest, or nap it again.
    func toggleSkipped(_ item: NapItem) {
        guard state.activeSession == nil, state.selection.contains(item) else { return }
        if state.skipped.contains(item) {
            state.skipped.remove(item)
        } else {
            state.skipped.insert(item)
        }
        persist()
    }

    func isSkipped(_ item: NapItem) -> Bool {
        state.skipped.contains(item)
    }

    /// Chosen apps, most-rested first. iOS doesn't let apps read Screen Time usage,
    /// so your own rest history is the signal.
    func quickToggleItems() -> [NapItem] {
        let items = state.selection.items
        let counts = Dictionary(uniqueKeysWithValues: items.map { item in
            (item, state.sessions.filter { $0.rested?.contains(item) == true }.count)
        })
        return items.enumerated()
            .sorted { a, b in
                let (ca, cb) = (counts[a.element] ?? 0, counts[b.element] ?? 0)
                return ca != cb ? ca > cb : a.offset < b.offset
            }
            .map(\.element)
    }

    // MARK: Tap-only setup

    var tapSetupPuck: Puck? { state.pucks.first { $0.id == tapSetupPuckID } }

    func showTapSetup(for puckID: UUID? = nil, returningTo destination: Route? = nil) {
        tapSetupPuckID = puckID ?? themePuck?.id
        tapSetupReturn = destination ?? (state.activeSession == nil ? .ready : .resting)
        route = .tapSetup
    }

    /// `done` records that the automation is set up for this puck; "maybe later" passes false.
    func finishTapSetup(done: Bool) {
        if done, let id = tapSetupPuckID { markTapOnlyReady(id) }
        route = tapSetupReturn
    }

    // MARK: Rest and wake

    /// An in-app puck tap. Any of your pucks rests apps from Ready and wakes them from Resting.
    func puckTap() async {
        guard !isReading, route == .ready || route == .resting else { return }
        isReading = true
        notice = nil
        defer { isReading = false }

        let read: TagRead
        do {
            read = try await reader.read()
        } catch {
            show(error)
            return
        }

        guard let hash = PuckVerifier.hash(for: read),
              let puck = state.pucks.first(where: { $0.tagHash == hash }) else {
            notice = "// not your puck"
            return
        }

        state.themePuckID = puck.id
        if state.activeSession != nil {
            endRest(emergency: false)
        } else if activeSelection.isEmpty {
            notice = "// every app is switched off"
            persist()
        } else {
            startRest(puckID: puck.id)
        }
    }

    /// Called by the "Rest or wake" App Intent from a Shortcuts NFC automation.
    /// Shortcuts only fires for the tag the user scanned when creating the automation,
    /// but it can't tell reset which tag that was, so there's no secret check here.
    /// Returns true if apps are now napping.
    @discardableResult
    func toggleFromShortcut() throws -> Bool {
        reload()
        guard !state.pucks.isEmpty, !state.selection.isEmpty else { throw ToggleError.notSetUp }
        if state.activeSession != nil {
            endRest(emergency: false)
            return false
        }
        guard !activeSelection.isEmpty else { throw ToggleError.nothingToRest }
        startRest(puckID: nil)
        return true
    }

    /// Wakes apps without a puck. Limited (see `EmergencyAllowance`).
    @discardableResult
    func emergencyWake() -> Bool {
        guard state.activeSession != nil, emergency.consume() else { return false }
        endRest(emergency: true)
        return true
    }

    func finishWake() {
        lastRest = nil
        route = .ready
    }

    private func startRest(puckID: UUID?) {
        let resting = activeSelection
        blocking.rest(resting)
        state.sessions.append(RestSession(puckID: puckID, startedAt: now(), rested: resting))
        persist()
        route = .resting
    }

    private func endRest(emergency: Bool) {
        guard let index = state.sessions.lastIndex(where: { $0.endedAt == nil }) else { return }
        blocking.wake()
        state.sessions[index].endedAt = now()
        state.sessions[index].emergency = emergency
        lastRest = state.sessions[index]
        persist()
        route = .wake
    }

    // MARK: Settings

    /// Forgets every puck, app and rest. Not allowed while apps are napping.
    func eraseEverything() {
        guard state.activeSession == nil else { return }
        state = ResetState()
        persist()
        pairStatus = .idle
        route = .welcome
    }

    // MARK: Stats

    /// Total rest time today, including the current rest.
    func restedToday() -> TimeInterval {
        rested(on: now())
    }

    /// Average rest per day across days with any rest in the last 14 days.
    func dailyAverage() -> TimeInterval {
        let days = (0..<14).compactMap { calendar.date(byAdding: .day, value: -$0, to: now()) }
        let totals = days.map(rested(on:)).filter { $0 > 0 }
        return totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
    }

    /// Consecutive days ending today (or yesterday, if today has no rest yet) with at
    /// least one rest ended by a puck.
    func streak() -> Int {
        let restDays = Set(state.sessions
            .filter { $0.endedAt != nil && !$0.emergency }
            .map { calendar.startOfDay(for: $0.startedAt) })
        var day = calendar.startOfDay(for: now())
        if !restDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while restDays.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Monday-to-Sunday dots for the current week: true where a day has a completed rest.
    func weekDots() -> [Bool] {
        var cal = calendar
        cal.firstWeekday = 2
        guard let week = cal.dateInterval(of: .weekOfYear, for: now()) else { return Array(repeating: false, count: 7) }
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: week.start)!
            return state.sessions.contains { $0.endedAt != nil && !$0.emergency && cal.isDate($0.startedAt, inSameDayAs: day) }
        }
    }

    private func rested(on day: Date) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return state.sessions.reduce(0) { total, session in
            let end = min(session.endedAt ?? now(), interval.end)
            let start = max(session.startedAt, interval.start)
            return total + max(0, end.timeIntervalSince(start))
        }
    }

    // MARK: Helpers

    private func persist() {
        store.save(state)
        puckStore.save(state.pucks)
        shared?.casing = casing
        shared?.restingSince = restingSince
    }

    private func show(_ error: Error) {
        if (error as? TagReaderError) == .cancelled { return }
        notice = "// " + (error.localizedDescription).lowercased()
    }
}
