import Foundation

/// A paired puck. The secret lives on the tag; we only keep a hash of UID + secret.
struct Puck: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Where it lives, e.g. "Desk" or "Bedside".
    var name: String
    var tagHash: String
    var casing: Casing
    var pairedAt: Date
    /// The user has set up the Shortcuts NFC automation for this puck.
    var tapOnlyReady = false

    /// Short id shown on the pairing card, e.g. "rs-04f2".
    var displayID: String { "rs-" + tagHash.prefix(4) }

    init(id: UUID = UUID(), name: String = "Puck", tagHash: String, casing: Casing, pairedAt: Date, tapOnlyReady: Bool = false) {
        self.id = id
        self.name = name
        self.tagHash = tagHash
        self.casing = casing
        self.pairedAt = pairedAt
        self.tapOnlyReady = tapOnlyReady
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Puck"
        tagHash = try c.decode(String.self, forKey: .tagHash)
        casing = try c.decode(Casing.self, forKey: .casing)
        pairedAt = try c.decode(Date.self, forKey: .pairedAt)
        tapOnlyReady = try c.decodeIfPresent(Bool.self, forKey: .tapOnlyReady) ?? false
    }
}

/// One rest, from tap to wake.
struct RestSession: Codable, Equatable, Identifiable {
    var id = UUID()
    /// The puck that started the rest, or nil when started from the Shortcuts automation.
    var puckID: UUID?
    var startedAt: Date
    var endedAt: Date?
    /// Ended with an emergency wake instead of a puck. Doesn't count toward the streak.
    var emergency = false
    /// Exactly what napped, used to sort the quick toggles by how often you rest each app.
    var rested: NapSelection?

    var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}

/// Everything reset remembers on this device. Pucks are kept separately in the
/// iCloud Keychain (see `PuckStore`) so they survive reinstalls and sync to your other devices.
struct ResetState: Codable, Equatable {
    var pucks: [Puck] = []
    var selection = NapSelection()
    /// Chosen apps switched off on the home screen. They stay awake on the next rest.
    var skipped = NapSelection()
    var sessions: [RestSession] = []
    /// The puck that themes the app: the one you tapped most recently.
    var themePuckID: UUID?

    /// The open session, if apps are napping right now.
    var activeSession: RestSession? { sessions.last { $0.endedAt == nil } }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pucks = try c.decodeIfPresent([Puck].self, forKey: .pucks) ?? []
        selection = try c.decodeIfPresent(NapSelection.self, forKey: .selection) ?? NapSelection()
        skipped = try c.decodeIfPresent(NapSelection.self, forKey: .skipped) ?? NapSelection()
        sessions = try c.decodeIfPresent([RestSession].self, forKey: .sessions) ?? []
        themePuckID = try c.decodeIfPresent(UUID.self, forKey: .themePuckID)
    }
}

protocol StateStore {
    func load() -> ResetState
    func save(_ state: ResetState)
}

/// Persists `ResetState` as JSON in the App Group container.
struct FileStateStore: StateStore {
    var url = SharedState.containerURL.appendingPathComponent("reset-state.json")

    func load() -> ResetState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(ResetState.self, from: data) else { return ResetState() }
        return state
    }

    func save(_ state: ResetState) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            assertionFailure("Couldn't save reset state: \(error)")
        }
    }
}

final class InMemoryStateStore: StateStore {
    var state: ResetState
    init(_ state: ResetState = ResetState()) { self.state = state }
    func load() -> ResetState { state }
    func save(_ state: ResetState) { self.state = state }
}

// MARK: Pucks

/// Where paired pucks live. Pair once, remembered forever.
protocol PuckStore {
    func load() -> [Puck]
    func save(_ pucks: [Puck])
}

/// Pucks in the iCloud Keychain: they survive deleting the app and sync to your
/// other iPhones on the same Apple ID (when iCloud Keychain is on).
struct KeychainPuckStore: PuckStore {
    private let account = "reset.pucks"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
    }

    func load() -> [Puck] {
        var q = query
        q[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let pucks = try? JSONDecoder().decode([Puck].self, from: data) else { return [] }
        return pucks
    }

    func save(_ pucks: [Puck]) {
        guard let data = try? JSONEncoder().encode(pucks) else { return }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

final class InMemoryPuckStore: PuckStore {
    var pucks: [Puck]
    init(_ pucks: [Puck] = []) { self.pucks = pucks }
    func load() -> [Puck] { pucks }
    func save(_ pucks: [Puck]) { self.pucks = pucks }
}
