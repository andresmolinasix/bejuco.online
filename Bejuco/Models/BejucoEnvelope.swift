import Foundation

enum BejucoMessageType: String, Codable, CaseIterable, Identifiable {
    case distress = "DISTRESS"
    case safe = "SAFE"
    case supplyRequest = "SUPPLY_REQUEST"
    case supplyAvailable = "SUPPLY_AVAILABLE"
    case medicalRequest = "MEDICAL_REQUEST"
    case shelterStatus = "SHELTER_STATUS"
    case acknowledgement = "ACK"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distress: return "Necesito ayuda"
        case .safe: return "Estoy a salvo"
        case .supplyRequest: return "Solicitud de insumos"
        case .supplyAvailable: return "Insumos disponibles"
        case .medicalRequest: return "Solicitud médica"
        case .shelterStatus: return "Estado de refugio"
        case .acknowledgement: return "Confirmación"
        }
    }
}

enum BejucoPriority: String, Codable, CaseIterable, Identifiable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case normal = "NORMAL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .critical: return "Crítica"
        case .high: return "Alta"
        case .normal: return "Normal"
        }
    }
}

enum NodeRole: String, Codable, CaseIterable, Identifiable {
    case affected = "AFFECTED"
    case relay = "RELAY"
    case collectionCenter = "COLLECTION_CENTER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .affected: return "Persona afectada"
        case .relay: return "Punto de relevo"
        case .collectionCenter: return "Centro de acopio"
        }
    }
}

struct GeoLocation: Codable, Hashable {
    let lat: Double
    let lon: Double
    let accuracy: Double?

    init(lat: Double, lon: Double, accuracy: Double? = nil) {
        self.lat = lat
        self.lon = lon
        self.accuracy = accuracy
    }
}

/// Canonical, transport-independent emergency packet.
/// Timestamps are Unix milliseconds so Android, iOS and embedded nodes can
/// serialize the same shape without depending on language-specific dates.
struct BejucoEnvelope: Codable, Identifiable, Hashable {
    static let protocolVersion = 1

    let version: Int
    let messageId: String
    let eventId: String
    let type: BejucoMessageType
    let originId: String
    let createdAt: Int64
    let expiresAt: Int64
    let location: GeoLocation?
    let priority: BejucoPriority
    var hopCount: Int
    let hopLimit: Int
    let payload: [String: String]
	var originPublicKey: String?
	var signature: String?

    var id: String { messageId }

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1_000)
    }

    var expirationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(expiresAt) / 1_000)
    }

    var isExpired: Bool {
        Date() >= expirationDate
    }

    var canRelay: Bool {
        !isExpired && hopCount < hopLimit
    }

    init(
        messageId: String = UUID().uuidString,
        eventId: String = "local-event",
        type: BejucoMessageType,
        originId: String,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        location: GeoLocation?,
        priority: BejucoPriority,
        hopCount: Int = 0,
        hopLimit: Int = 20,
        payload: [String: String] = [:],
        originPublicKey: String? = nil,
        signature: String? = nil
    ) {
        self.version = Self.protocolVersion
        self.messageId = messageId
        self.eventId = eventId
        self.type = type
        self.originId = originId
        self.createdAt = Int64(createdAt.timeIntervalSince1970 * 1_000)
        let expiration = expiresAt ?? createdAt.addingTimeInterval(24 * 60 * 60)
        self.expiresAt = Int64(expiration.timeIntervalSince1970 * 1_000)
        self.location = location
        self.priority = priority
        self.hopCount = hopCount
        self.hopLimit = hopLimit
        self.payload = payload
        self.originPublicKey = originPublicKey
        self.signature = signature
    }

    func relayed() -> BejucoEnvelope {
        var copy = self
        copy.hopCount = min(hopCount + 1, hopLimit)
        return copy
    }

    /// Hop count is relay metadata. It is intentionally normalized for the
    /// signing copy so a relay can increment it without invalidating the
    /// origin's signature.
    func signingCopy() -> BejucoEnvelope {
        var copy = self
        copy.hopCount = 0
        copy.signature = nil
        return copy
    }
}
