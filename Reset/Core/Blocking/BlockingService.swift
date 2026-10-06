import FamilyControls
import Foundation
import ManagedSettings

/// Puts apps to sleep and wakes them.
///
/// v1 uses `.individual` authorisation (the user restricts their own phone). A future
/// parent or school mode is a new implementation using `.child` authorisation.
protocol BlockingService: AnyObject {
    var isAuthorized: Bool { get }
    func requestAuthorization() async throws
    func rest(_ selection: NapSelection)
    func wake()
}

/// Real blocking via Screen Time. Needs the Family Controls entitlement, so it only
/// works in the full `Reset` target on a physical device.
final class ScreenTimeBlockingService: BlockingService {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("reset"))

    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func rest(_ selection: NapSelection) {
        let family = selection.family
        store.shield.applications = family.applicationTokens.isEmpty ? nil : family.applicationTokens
        store.shield.applicationCategories = family.categoryTokens.isEmpty ? nil : .specific(family.categoryTokens)
        store.shield.webDomains = family.webDomainTokens.isEmpty ? nil : family.webDomainTokens
        store.shield.webDomainCategories = family.categoryTokens.isEmpty ? nil : .specific(family.categoryTokens)
    }

    func wake() {
        store.clearAllSettings()
    }
}

/// Records calls instead of blocking. Used by the demo build and tests.
final class MockBlockingService: BlockingService {
    private(set) var isAuthorized = false
    private(set) var resting: NapSelection?

    func requestAuthorization() async throws {
        isAuthorized = true
    }

    func rest(_ selection: NapSelection) {
        resting = selection
    }

    func wake() {
        resting = nil
    }
}
