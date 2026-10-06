import Foundation

/// The small slice of state the shield extension needs: which casing to paint with
/// and when the rest started. Lives in the App Group so both processes can read it.
struct SharedState {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedState.groupDefaults) {
        self.defaults = defaults
    }

    /// App Group ID comes from Info.plist (`ResetAppGroup`), which is set from Config.xcconfig.
    static var appGroupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "ResetAppGroup") as? String
    }

    /// Falls back to standard defaults when the App Group is unavailable (e.g. the demo
    /// build signed with a free team).
    static var groupDefaults: UserDefaults {
        appGroupID.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// Container for the app's JSON store. Falls back to Application Support.
    static var containerURL: URL {
        if let id = appGroupID,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    var casing: Casing {
        get {
            guard let data = defaults.data(forKey: Keys.casing),
                  let casing = try? JSONDecoder().decode(Casing.self, from: data) else { return .default }
            return casing
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Keys.casing)
        }
    }

    var restingSince: Date? {
        get { defaults.object(forKey: Keys.restingSince) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Keys.restingSince) }
    }

    private enum Keys {
        static let casing = "reset.casing"
        static let restingSince = "reset.restingSince"
    }
}

enum DurationFormat {
    /// "01:24:09"
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }

    /// "3h 12m", "12m"
    static func short(_ interval: TimeInterval) -> String {
        let m = max(0, Int(interval)) / 60
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
