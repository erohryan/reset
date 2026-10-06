import Foundation

/// Simulates a puck for the demo build, the Simulator and tests.
/// Behaves like a real tag: pairing writes the payload, later reads return it.
final class MockTagReader: TagReader {
    var uid: Data
    var storedPayload: PuckPayload?
    var delay: Duration
    /// Set to make the next read fail (tests).
    var nextError: TagReaderError?
    /// Demo build: each pairing simulates a different blank tag, so you can add several pucks.
    var newTagEachPair = false

    init(uid: Data = Data([0x04, 0xF2, 0x1A, 0x9C, 0x33, 0x80, 0x01]), delay: Duration = .milliseconds(1300)) {
        self.uid = uid
        self.delay = delay
    }

    func read() async throws -> TagRead {
        try await simulateTap()
        return TagRead(uid: uid, payload: storedPayload)
    }

    func pair(writing payload: @escaping (PuckPayload?) -> PuckPayload) async throws -> TagRead {
        try await simulateTap()
        if newTagEachPair {
            uid = Data((0..<7).map { _ in UInt8.random(in: 0...255) })
            storedPayload = nil
        }
        let before = TagRead(uid: uid, payload: storedPayload)
        storedPayload = payload(storedPayload)
        return before
    }

    private func simulateTap() async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let error = nextError {
            nextError = nil
            throw error
        }
    }
}
