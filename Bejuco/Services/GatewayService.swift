import Foundation
import Network
import SwiftUI

@MainActor
final class GatewayService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var statusText = "Comprobando conectividad…"
    @Published private(set) var isUploading = false
    @Published private(set) var lastUploadMessage: String?

    var onConnectivityRestored: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "online.bejuco.gateway-monitor")
    private let store: MessageStore
    private let settings: SettingsStore

    init(store: MessageStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isConnected = path.status == .satisfied
                statusText = isConnected ? "Internet disponible" : "Sin Internet · usando mesh"
                if isConnected {
                    onConnectivityRestored?()
                    syncPending()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func syncPending() {
        guard isConnected, !isUploading else { return }
        guard let endpoint = URL(string: settings.gatewayURL), !settings.gatewayURL.isEmpty else {
            lastUploadMessage = "Configura el endpoint del gateway."
            return
        }

        let pending = store.pendingUpload
        guard !pending.isEmpty else {
            lastUploadMessage = "No hay paquetes pendientes."
            return
        }

        let ids = Set(pending.map(\.messageId))
        store.markUploading(ids)
        isUploading = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try ProtocolCodec.encode(GatewayBatch(messages: pending))
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                store.markUploaded(ids)
                lastUploadMessage = "\(pending.count) paquete(s) entregado(s) al gateway."
            } catch {
                store.markFailed(ids)
                lastUploadMessage = "No se pudo entregar el lote: \(error.localizedDescription)"
            }
            isUploading = false
        }
    }
}

private struct GatewayBatch: Encodable {
    let messages: [BejucoEnvelope]
}
