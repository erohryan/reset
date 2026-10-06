import FamilyControls
import Foundation
import ManagedSettings

/// The apps the user chose to nap.
///
/// Real builds use Apple's opaque tokens from `FamilyActivityPicker` (iOS never tells
/// apps which apps are installed). The demo build uses named placeholder apps.
struct NapSelection: Codable, Equatable {
    var family = FamilyActivitySelection()
    var demoApps: [DemoApp] = []

    var count: Int {
        family.applicationTokens.count
            + family.categoryTokens.count
            + family.webDomainTokens.count
            + demoApps.count
    }

    var isEmpty: Bool { count == 0 }

    var items: [NapItem] {
        family.applicationTokens.map(NapItem.app)
            + family.categoryTokens.map(NapItem.category)
            + family.webDomainTokens.map(NapItem.web)
            + demoApps.map(NapItem.demo)
    }

    func contains(_ item: NapItem) -> Bool {
        switch item {
        case .app(let token): family.applicationTokens.contains(token)
        case .category(let token): family.categoryTokens.contains(token)
        case .web(let token): family.webDomainTokens.contains(token)
        case .demo(let app): demoApps.contains(app)
        }
    }

    mutating func insert(_ item: NapItem) {
        guard !contains(item) else { return }
        switch item {
        case .app(let token): family.applicationTokens.insert(token)
        case .category(let token): family.categoryTokens.insert(token)
        case .web(let token): family.webDomainTokens.insert(token)
        case .demo(let app): demoApps.append(app)
        }
    }

    mutating func remove(_ item: NapItem) {
        switch item {
        case .app(let token): family.applicationTokens.remove(token)
        case .category(let token): family.categoryTokens.remove(token)
        case .web(let token): family.webDomainTokens.remove(token)
        case .demo(let app): demoApps.removeAll { $0 == app }
        }
    }

    /// This selection without anything in `other`.
    func subtracting(_ other: NapSelection) -> NapSelection {
        var result = self
        other.items.forEach { result.remove($0) }
        return result
    }

    /// Only the items also in `other` (drops skipped apps that are no longer chosen).
    func intersecting(_ other: NapSelection) -> NapSelection {
        var result = NapSelection()
        items.filter(other.contains).forEach { result.insert($0) }
        return result
    }
}

/// A placeholder app for the demo build, matching the prototype's list.
struct DemoApp: Codable, Hashable, Identifiable {
    var name: String
    var initial: String
    var id: String { name }

    static let all: [DemoApp] = [
        DemoApp(name: "Instagram", initial: "I"),
        DemoApp(name: "TikTok", initial: "T"),
        DemoApp(name: "X", initial: "X"),
        DemoApp(name: "YouTube", initial: "Y"),
        DemoApp(name: "Reddit", initial: "R"),
        DemoApp(name: "Snapchat", initial: "S"),
        DemoApp(name: "Messages", initial: "M"),
        DemoApp(name: "Maps", initial: "P"),
    ]

    /// On by default in the prototype's picker.
    static let defaults = Array(all.prefix(6))
}

enum NapItem: Identifiable, Hashable {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
    case web(WebDomainToken)
    case demo(DemoApp)

    var id: Self { self }
}
