import Foundation
import Security

/// How many emergency wakes are left. Kept in the Keychain so it survives app updates.
protocol EmergencyAllowance: AnyObject {
    var remaining: Int { get }
    /// Uses one wake. Returns false when none are left.
    func consume() -> Bool
}

final class KeychainEmergencyAllowance: EmergencyAllowance {
    static let total = 3
    private let account = "reset.emergency.remaining"

    var remaining: Int {
        read() ?? Self.total
    }

    func consume() -> Bool {
        let left = remaining
        guard left > 0 else { return false }
        write(left - 1)
        return true
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
    }

    private func read() -> Int? {
        var q = query
        q[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return Int(string)
    }

    private func write(_ value: Int) {
        let data = Data(String(value).utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

final class InMemoryEmergencyAllowance: EmergencyAllowance {
    private(set) var remaining: Int
    init(remaining: Int = KeychainEmergencyAllowance.total) { self.remaining = remaining }
    func consume() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }
}
