import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let identity: IdentityService
    let settings: SettingsStore
    let store: MessageStore
    let location: LocationService
    let mesh: MeshService
    let gateway: GatewayService
    let earthquakeService: EarthquakeService
    let backgroundTasks: BackgroundTaskCoordinator
    let notifications: NotificationService

    @Published private(set) var earthquakes: [EarthquakeEvent] = []
    @Published private(set) var latestEarthquake: EarthquakeEvent?
    @Published private(set) var feedbackMessage: String?
    @Published private(set) var lastSecurityMessage: String?
    @Published private(set) var isRefreshingEarthquakes = false
    @Published var selectedTab: BejucoTab = .home

    init() {
        identity = IdentityService()
        settings = SettingsStore()
        store = MessageStore()
        location = LocationService()
        mesh = MeshService(nodeId: identity.nodeId)
        gateway = GatewayService(store: store, settings: settings)
        earthquakeService = EarthquakeService()
        backgroundTasks = BackgroundTaskCoordinator()
        notifications = NotificationService()
        notifications.onNotificationOpened = { [weak self] in
            self?.selectedTab = .alerts
        }

        mesh.messageProvider = { [weak self] in
            self?.store.activeRelayMessages ?? []
        }
        mesh.onEnvelopeReceived = { [weak self] envelope, transport in
            self?.receive(envelope, via: transport)
        }
        gateway.onConnectivityRestored = { [weak self] in
            self?.refreshEarthquakes()
        }
        backgroundTasks.configure(app: self)
        start()
    }

    func start() {
        notifications.requestAuthorization()
        mesh.start()
        gateway.start()
        backgroundTasks.registerAndSchedule()
    }

    func refreshEarthquakes() {
        guard !isRefreshingEarthquakes else { return }
        isRefreshingEarthquakes = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let events = try await earthquakeService.fetchLatest()
                earthquakes = events
                latestEarthquake = events.first
                feedbackMessage = events.isEmpty ? "No se encontraron eventos recientes." : "Alerta sísmica actualizada."
            } catch {
                feedbackMessage = "No se pudo consultar USGS: \(error.localizedDescription)"
            }
            isRefreshingEarthquakes = false
        }
    }

    @discardableResult
    func publishDistress(
        name: String,
        phone: String,
        contactName: String,
        notes: String,
        priority: BejucoPriority
    ) -> Bool {
        guard let location = location.currentLocation else {
            feedbackMessage = "Activa la ubicación antes de enviar un SOS."
            return false
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            feedbackMessage = "Escribe tu nombre para identificar el paquete."
            return false
        }

        let envelope = BejucoEnvelope(
            eventId: latestEarthquake?.id ?? "local-event",
            type: .distress,
            originId: identity.nodeId,
            location: location,
            priority: priority,
            payload: [
                "name": name,
                "phone": phone,
                "contactName": contactName,
                "notes": notes
            ]
        )
        let signed = identity.sign(envelope)
        if store.insert(signed) {
            mesh.announceLocalInventory()
            gateway.syncPending()
            feedbackMessage = "SOS guardado y anunciado por mesh."
            return true
        }
        feedbackMessage = "Este paquete ya existe en el almacén local."
        return false
    }

    @discardableResult
    func publishSafe(notes: String) -> Bool {
        let envelope = BejucoEnvelope(
            eventId: latestEarthquake?.id ?? "local-event",
            type: .safe,
            originId: identity.nodeId,
            location: location.currentLocation,
            priority: .normal,
            payload: [
                "name": settings.displayName,
                "contactName": settings.emergencyContact,
                "notes": notes
            ]
        )
        let signed = identity.sign(envelope)
        if store.insert(signed) {
            mesh.announceLocalInventory()
            gateway.syncPending()
            feedbackMessage = "Estado de seguridad guardado y anunciado."
            return true
        }
        feedbackMessage = "Este paquete ya existe en el almacén local."
        return false
    }

    @discardableResult
    func publishSupplyRequest(item: String, quantity: String, notes: String) -> Bool {
        guard !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            feedbackMessage = "Indica qué insumo se necesita."
            return false
        }
        let envelope = BejucoEnvelope(
            eventId: latestEarthquake?.id ?? "local-event",
            type: .supplyRequest,
            originId: identity.nodeId,
            location: location.currentLocation,
            priority: .high,
            payload: ["item": item, "quantity": quantity, "notes": notes]
        )
        let signed = identity.sign(envelope)
        if store.insert(signed) {
            mesh.announceLocalInventory()
            gateway.syncPending()
            feedbackMessage = "Solicitud de insumos guardada y anunciada."
            return true
        }
        feedbackMessage = "Este paquete ya existe en el almacén local."
        return false
    }

    private func receive(_ envelope: BejucoEnvelope, via transport: MeshEnvelopeTransport) {
        guard envelope.version <= BejucoEnvelope.protocolVersion else {
            feedbackMessage = "Se ignoró un paquete de una versión futura."
            return
        }

        guard envelope.expiresAt > envelope.createdAt,
              !envelope.isExpired,
              envelope.hopCount >= 0,
              envelope.hopLimit > 0,
              envelope.hopCount <= envelope.hopLimit else {
            lastSecurityMessage = "Se rechazó un paquete expirado o mal formado."
            return
        }

        guard let signature = envelope.signature,
              !signature.isEmpty,
              identity.verify(envelope) else {
            lastSecurityMessage = "Se rechazó un paquete con firma inválida."
            return
        }

        if store.insert(envelope) {
            if envelope.type == .distress {
                notifications.scheduleDistressNotification(for: envelope)
            }
            // BitChat already relays the opaque packet with a decremented outer
            // TTL. The legacy transport still needs the app-level inventory
            // announcement to perform store-and-forward.
            if case .legacy = transport {
                mesh.announceLocalInventory()
            }
            gateway.syncPending()
            feedbackMessage = "Nuevo paquete recibido y persistido."
        }
    }
}
