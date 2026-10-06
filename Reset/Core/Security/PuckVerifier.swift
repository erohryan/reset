import CryptoKit
import Foundation

/// Ties a puck to its tag: SHA-256 of the factory UID plus the secret reset wrote to it.
enum PuckVerifier {
    static func hash(uid: Data, secret: Data) -> String {
        SHA256.hash(data: uid + secret).map { String(format: "%02x", $0) }.joined()
    }

    /// The hash for a read, or nil if the tag carries no reset payload.
    static func hash(for read: TagRead) -> String? {
        read.payload.map { hash(uid: read.uid, secret: $0.secret) }
    }
}
