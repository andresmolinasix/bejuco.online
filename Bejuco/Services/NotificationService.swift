import Foundation
import SwiftUI
import UserNotifications

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let distressCategoryIdentifier = "BEJUCO_DISTRESS"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastErrorMessage: String?

    var onNotificationOpened: (() -> Void)?

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
        registerCategories()
        refreshAuthorizationStatus()
    }

    var statusTitle: String {
        switch authorizationStatus {
        case .authorized:
            return "Activadas"
        case .provisional:
            return "Activadas provisionalmente"
        case .denied:
            return "Bloqueadas"
        case .notDetermined:
            return "Sin configurar"
        @unknown default:
            return "Estado desconocido"
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error {
                    self?.lastErrorMessage = "No se pudo configurar las notificaciones: \(error.localizedDescription)"
                }
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Shows an immediate local notification for a newly received, verified
    /// DISTRESS envelope. The message ID makes the request idempotent at the
    /// app layer because AppModel calls this only after a successful insert.
    func scheduleDistressNotification(for envelope: BejucoEnvelope) {
        let content = UNMutableNotificationContent()
        content.title = "SOS recibido"

        let name = envelope.payload["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            content.body = "\(name) solicita ayuda por la red Bejuco. Toca para ver los detalles."
        } else {
            content.body = "Se recibió una solicitud de ayuda por la red Bejuco. Toca para ver los detalles."
        }

        content.sound = .default
        content.categoryIdentifier = Self.distressCategoryIdentifier
        content.userInfo = [
            "messageId": envelope.messageId,
            "type": envelope.type.rawValue,
            "originId": envelope.originId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: "bejuco.distress.\(envelope.messageId)",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.lastErrorMessage = "No se pudo mostrar la alerta recibida: \(error.localizedDescription)"
            }
        }
    }

    private func registerCategories() {
        let category = UNNotificationCategory(
            identifier: Self.distressCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    // A mesh packet can arrive while the app is visible. Explicitly returning
    // banner/list/sound keeps the alert observable in that case too.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.onNotificationOpened?()
        }
        completionHandler()
    }
}
