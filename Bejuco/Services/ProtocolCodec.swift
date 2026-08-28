import CryptoKit
import Foundation

enum ProtocolCodecError: LocalizedError {
    case invalidSignature
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidSignature: return "La firma del paquete no es válida."
        case .unsupportedVersion(let version): return "Versión de protocolo no compatible: \(version)."
        }
    }
}

enum ProtocolCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    static func signingData(for envelope: BejucoEnvelope) throws -> Data {
        try encode(envelope.signingCopy())
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(for envelope: BejucoEnvelope) throws -> String {
        sha256(try encode(envelope))
    }
}

/// Wire representation used by Android's `BejucoEnvelope` implementation.
///
/// Android currently serializes the envelope with Gson in declaration order and
/// signs that exact UTF-8 JSON after normalizing `hopCount` to zero. Keeping
/// this encoder explicit prevents Swift's synthesized Codable implementation
/// from changing the cross-platform signing preimage.
enum AndroidEnvelopeCodec {
    static func encode(_ envelope: BejucoEnvelope) throws -> Data {
        var fields: [String] = []
        fields.append("\"version\":\(envelope.version)")
        fields.append("\"messageId\":\(try quote(envelope.messageId))")
        if let eventId = envelope.eventId {
            fields.append("\"eventId\":\(try quote(eventId))")
        }
        fields.append("\"type\":\(try quote(envelope.type.rawValue))")
        fields.append("\"originId\":\(try quote(envelope.originId))")
        if let originPublicKey = envelope.originPublicKey {
            fields.append("\"originPublicKey\":\(try quote(originPublicKey))")
        }
        fields.append("\"createdAt\":\(envelope.createdAt)")
        fields.append("\"expiresAt\":\(envelope.expiresAt)")

        if let location = envelope.location {
            var locationFields = [
                "\"lat\":\(try jsonNumber(location.lat))",
                "\"lon\":\(try jsonNumber(location.lon))"
            ]
            if let accuracy = location.accuracy {
                locationFields.append("\"accuracy\":\(try jsonNumber(Float(accuracy)))")
            }
            fields.append("\"location\":{\(locationFields.joined(separator: ","))}")
        }

        fields.append("\"priority\":\(try quote(envelope.priority.rawValue))")
        fields.append("\"hopCount\":\(envelope.hopCount)")
        fields.append("\"hopLimit\":\(envelope.hopLimit)")

        let payloadFields = try envelope.payload.keys.sorted().map { key in
            "\(try quote(key)):\(try quote(envelope.payload[key] ?? ""))"
        }
        fields.append("\"payload\":{\(payloadFields.joined(separator: ","))}")
        if let signature = envelope.signature {
            fields.append("\"signature\":\(try quote(signature))")
        }

        return Data("{\(fields.joined(separator: ","))}".utf8)
    }

    private static func quote(_ value: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(data: try encoder.encode(value), encoding: .utf8)!
    }

    private static func jsonNumber<T: LosslessStringConvertible>(_ value: T) throws -> String {
        let result = String(value)
        guard !result.isEmpty, !result.contains("nan"), !result.contains("inf") else {
            throw ProtocolCodecError.invalidSignature
        }
        return result
    }

    static func signingData(for envelope: BejucoEnvelope) throws -> Data {
        var unsigned = envelope
        unsigned.hopCount = 0
        unsigned.signature = nil
        return try encode(unsigned)
    }

    static func decode(_ data: Data) throws -> BejucoEnvelope {
        try JSONDecoder().decode(BejucoEnvelope.self, from: data)
    }
}
