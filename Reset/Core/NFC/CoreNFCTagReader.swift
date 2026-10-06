import CoreNFC
import Foundation

/// Real NFC via Core NFC. NTAG213/215/216 show up as MIFARE Ultralight tags.
///
/// iOS shows its own "Ready to Scan" sheet during a read; `alertMessage` sets its copy.
final class CoreNFCTagReader: NSObject, TagReader, NFCTagReaderSessionDelegate, @unchecked Sendable {
    private enum Mode {
        case read
        case pair((PuckPayload?) -> PuckPayload)
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<TagRead, Error>?
    private var mode: Mode = .read

    func read() async throws -> TagRead {
        try await begin(.read)
    }

    func pair(writing payload: @escaping (PuckPayload?) -> PuckPayload) async throws -> TagRead {
        try await begin(.pair(payload))
    }

    private func begin(_ mode: Mode) async throws -> TagRead {
        guard NFCTagReaderSession.readingAvailable else { throw TagReaderError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.continuation = continuation
                self.mode = mode
                self.session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
                self.session?.alertMessage = "Hold your phone to the puck."
                self.session?.begin()
            }
        }
    }

    private func finish(_ result: Result<TagRead, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: NFCTagReaderSessionDelegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let code = (error as? NFCReaderError)?.code
        switch code {
        case .readerSessionInvalidationErrorUserCanceled, .readerSessionInvalidationErrorSessionTimeout:
            finish(.failure(TagReaderError.cancelled))
        default:
            finish(.failure(TagReaderError.failed(error.localizedDescription)))
        }
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first, case let .miFare(tag) = first else {
            fail(session, TagReaderError.notAPuck)
            return
        }
        session.connect(to: first) { error in
            if error != nil { return self.fail(session, .failed("Couldn't read the puck. Try again.")) }
            let uid = tag.identifier

            tag.queryNDEFStatus { status, _, error in
                if error != nil || status == .notSupported { return self.fail(session, .notAPuck) }

                tag.readNDEF { message, _ in
                    // A blank tag reports an error here; treat it as "no payload".
                    let existing = message.flatMap(Self.payload(in:))
                    let read = TagRead(uid: uid, payload: existing)

                    switch self.mode {
                    case .read:
                        self.succeed(session, read)
                    case .pair(let makePayload):
                        guard status == .readWrite else { return self.fail(session, .readOnly) }
                        guard let message = Self.message(for: makePayload(existing)) else {
                            return self.fail(session, .failed("Couldn't prepare the puck."))
                        }
                        tag.writeNDEF(message) { error in
                            if let error { return self.fail(session, .failed(error.localizedDescription)) }
                            self.succeed(session, read)
                        }
                    }
                }
            }
        }
    }

    private func succeed(_ session: NFCTagReaderSession, _ read: TagRead) {
        finish(.success(read))
        session.alertMessage = "found it ✓"
        session.invalidate()
    }

    private func fail(_ session: NFCTagReaderSession, _ error: TagReaderError) {
        finish(.failure(error))
        session.invalidate(errorMessage: error.errorDescription ?? "Try again.")
    }

    // MARK: NDEF encoding

    private static func payload(in message: NFCNDEFMessage) -> PuckPayload? {
        let type = Data(PuckPayload.mimeType.utf8)
        guard let record = message.records.first(where: { $0.typeNameFormat == .media && $0.type == type }) else {
            return nil
        }
        return try? JSONDecoder().decode(PuckPayload.self, from: record.payload)
    }

    private static func message(for payload: PuckPayload) -> NFCNDEFMessage? {
        guard let json = try? JSONEncoder().encode(payload) else { return nil }
        let record = NFCNDEFPayload(
            format: .media,
            type: Data(PuckPayload.mimeType.utf8),
            identifier: Data(),
            payload: json
        )
        return NFCNDEFMessage(records: [record])
    }
}
