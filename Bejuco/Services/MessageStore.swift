import Foundation
import SwiftUI

enum UploadState: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
}

struct StoredMessage: Codable, Identifiable, Hashable {
    var envelope: BejucoEnvelope
    var uploadState: UploadState
    let storedAt: Int64

    var id: String { envelope.messageId }
}

@MainActor
final class MessageStore: ObservableObject {
    @Published private(set) var records: [StoredMessage] = []
    @Published private(set) var lastError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = support.appendingPathComponent("Bejuco", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("messages.json")
        }
        load()
    }

    var messages: [BejucoEnvelope] {
        records.map(\.envelope)
    }

    var pendingUpload: [BejucoEnvelope] {
        records.filter { $0.uploadState != .uploaded && !$0.envelope.isExpired }.map(\.envelope)
    }

    var activeRelayMessages: [BejucoEnvelope] {
        records.map(\.envelope).filter(\.canRelay)
    }

    @discardableResult
    func insert(_ envelope: BejucoEnvelope, uploadState: UploadState = .pending) -> Bool {
        if let index = records.firstIndex(where: { $0.id == envelope.messageId }) {
            // Keep the copy that has travelled the shortest path. This makes
            // deduplication deterministic while still improving relay budget.
            if envelope.hopCount < records[index].envelope.hopCount {
                records[index].envelope = envelope
                persist()
            }
            return false
        }

        records.append(StoredMessage(
            envelope: envelope,
            uploadState: uploadState,
            storedAt: Int64(Date().timeIntervalSince1970 * 1_000)
        ))
        records.sort { $0.envelope.createdAt > $1.envelope.createdAt }
        persist()
        return true
    }

    func markUploading(_ ids: Set<String>) {
        for index in records.indices where ids.contains(records[index].id) {
            records[index].uploadState = .uploading
        }
        persist()
    }

    func markUploaded(_ ids: Set<String>) {
        for index in records.indices where ids.contains(records[index].id) {
            records[index].uploadState = .uploaded
        }
        persist()
    }

    func markFailed(_ ids: Set<String>) {
        for index in records.indices where ids.contains(records[index].id) {
            records[index].uploadState = .failed
        }
        persist()
    }

    func retryFailedUploads() {
        for index in records.indices where records[index].uploadState == .failed {
            records[index].uploadState = .pending
        }
        persist()
    }

    func clearError() {
        lastError = nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            records = try JSONDecoder().decode([StoredMessage].self, from: data)
        } catch {
            lastError = "No se pudo leer el almacén local: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let data = try ProtocolCodec.encode(records)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            lastError = "No se pudo persistir el paquete: \(error.localizedDescription)"
        }
    }
}

