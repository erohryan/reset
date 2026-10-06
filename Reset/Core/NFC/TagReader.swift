import Foundation

/// What reset stores on a puck: a random secret (so a cloned UID alone can't wake
/// your apps) and the casing hue (so a Sage puck themes the app Sage).
struct PuckPayload: Codable, Equatable {
    static let mimeType = "application/vnd.reset.puck"

    var version: Int = 1
    var secret: Data
    var hue: Double?

    enum CodingKeys: String, CodingKey {
        case version = "v", secret = "s", hue = "h"
    }

    static func makeSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}

/// The result of holding the phone to a tag.
struct TagRead: Equatable {
    /// Factory serial number (7 bytes on NTAG213).
    var uid: Data
    /// The reset payload on the tag, if any.
    var payload: PuckPayload?
}

enum TagReaderError: LocalizedError, Equatable {
    case unavailable
    case cancelled
    case notAPuck
    case readOnly
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "NFC isn't available on this device."
        case .cancelled: "Cancelled."
        case .notAPuck: "That doesn't look like a puck."
        case .readOnly: "That tag is locked and can't be paired."
        case .failed(let message): message
        }
    }
}

/// Reads and pairs pucks. The Core NFC version talks to real tags; the mock
/// simulates the 1300ms read from the prototype.
protocol TagReader: AnyObject {
    /// Reads the UID and any reset payload.
    func read() async throws -> TagRead
    /// Reads the tag, then writes `payload` to it. Returns what was on the tag before.
    func pair(writing payload: @escaping (PuckPayload?) -> PuckPayload) async throws -> TagRead
}
