import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultGatewayURL = "https://bejuco-dev-ingest-api-w6gswgwgyq-uc.a.run.app/v1/messages/batch"

    private let defaults: UserDefaults

    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    @Published var phone: String {
        didSet { defaults.set(phone, forKey: Keys.phone) }
    }

    @Published var emergencyContact: String {
        didSet { defaults.set(emergencyContact, forKey: Keys.emergencyContact) }
    }

    @Published var gatewayURL: String {
        didSet { defaults.set(gatewayURL, forKey: Keys.gatewayURL) }
    }

    @Published var role: NodeRole {
        didSet { defaults.set(role.rawValue, forKey: Keys.role) }
    }

    @Published var relayingEnabled: Bool {
        didSet { defaults.set(relayingEnabled, forKey: Keys.relayingEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayName = defaults.string(forKey: Keys.displayName) ?? ""
        phone = defaults.string(forKey: Keys.phone) ?? ""
        emergencyContact = defaults.string(forKey: Keys.emergencyContact) ?? ""
        let storedGatewayURL = defaults.string(forKey: Keys.gatewayURL)
        if storedGatewayURL == nil || storedGatewayURL == "https://bejuco.online/v1/messages/batch" {
            gatewayURL = Self.defaultGatewayURL
        } else {
            gatewayURL = storedGatewayURL!
        }
        role = NodeRole(rawValue: defaults.string(forKey: Keys.role) ?? "AFFECTED") ?? .affected
        relayingEnabled = defaults.object(forKey: Keys.relayingEnabled) as? Bool ?? true
    }

    private enum Keys {
        static let displayName = "bejuco.displayName"
        static let phone = "bejuco.phone"
        static let emergencyContact = "bejuco.emergencyContact"
        static let gatewayURL = "bejuco.gatewayURL"
        static let role = "bejuco.role"
        static let relayingEnabled = "bejuco.relayingEnabled"
    }
}
