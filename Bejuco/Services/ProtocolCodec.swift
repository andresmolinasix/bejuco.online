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

