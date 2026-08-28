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
    private let gatewayId: String

    init(store: MessageStore, settings: SettingsStore, gatewayId: String) {
        self.store = store
        self.settings = settings
        self.gatewayId = gatewayId
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
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = try ProtocolCodec.encode(GatewayBatch(gatewayId: gatewayId, messages: pending))
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GatewayServiceError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    let detail = String(data: data, encoding: .utf8)
                    throw GatewayServiceError.httpStatus(http.statusCode, detail)
                }

                let result = try ProtocolCodec.decode(GatewayBatchResult.self, from: data)
                guard result.total == pending.count else {
                    throw GatewayServiceError.inconsistentResult(
                        accepted: result.accepted,
                        rejected: result.rejected,
                        total: result.total,
                        expected: pending.count
                    )
                }
                guard result.rejected == 0, result.accepted == pending.count else {
                    throw GatewayServiceError.rejected(
                        accepted: result.accepted,
                        rejected: result.rejected,
                        total: result.total
                    )
                }

                store.markUploaded(ids)
                lastUploadMessage = "\(result.accepted) paquete(s) entregado(s) al gateway."
            } catch {
                store.markFailed(ids)
                lastUploadMessage = "No se pudo entregar el lote: \(error.localizedDescription)"
            }
            isUploading = false
        }
    }
}

enum GatewayServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)
    case inconsistentResult(accepted: Int, rejected: Int, total: Int, expected: Int)
    case rejected(accepted: Int, rejected: Int, total: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "El gateway devolvió una respuesta inválida."
        case .httpStatus(let status, let detail):
            if let detail, !detail.isEmpty {
                return "El gateway respondió HTTP \(status): \(detail)"
            }
            return "El gateway respondió HTTP \(status)."
        case .inconsistentResult(let accepted, let rejected, let total, let expected):
            return "Respuesta inconsistente del gateway (aceptados: \(accepted), rechazados: \(rejected), total: \(total), esperado: \(expected))."
        case .rejected(let accepted, let rejected, let total):
            return "El gateway rechazó parte del lote (aceptados: \(accepted), rechazados: \(rejected), total: \(total))."
        }
    }
}

struct GatewayBatch: Encodable {
    let gatewayId: String
    let messages: [BejucoEnvelope]
}

struct GatewayBatchResult: Decodable {
    let accepted: Int
    let rejected: Int
    let total: Int
}
