import CryptoKit
import Foundation
import Security

enum IdentityServiceError: LocalizedError {
    case keychainFailure(OSStatus)
    case invalidStoredKey

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status): return "No se pudo guardar la identidad local (\(status))."
        case .invalidStoredKey: return "La identidad almacenada no se puede leer."
        }
    }
}

private final class KeychainStore {
    private let service = "online.bejuco.ios.identity"
    private let account = "ed25519-signing-key-v1"

    func read() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw IdentityServiceError.keychainFailure(status) }
        return result as? Data
    }

    func write(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if update != errSecSuccess { throw IdentityServiceError.keychainFailure(update) }
        } else if status != errSecSuccess {
            throw IdentityServiceError.keychainFailure(status)
        }
    }
}

final class IdentityService {
    let nodeId: String
    let publicKey: String

    private let privateKey: Curve25519.Signing.PrivateKey

    init() {
        let keychain = KeychainStore()
        let loadedKey: Curve25519.Signing.PrivateKey

		if let stored = try? keychain.read(), let decoded = try? Curve25519.Signing.PrivateKey(rawRepresentation: stored) {
            loadedKey = decoded
        } else {
            let generated = Curve25519.Signing.PrivateKey()
            try? keychain.write(generated.rawRepresentation)
            loadedKey = generated
        }

        privateKey = loadedKey
        let publicData = loadedKey.publicKey.rawRepresentation
        publicKey = publicData.map { String(format: "%02x", $0) }.joined()
        // Android derives both its mesh peer ID and Bejuco origin ID from the
        // UTF-8 bytes of the lowercase public-key hex string, then keeps the
        // first eight digest bytes (16 hexadecimal characters).
        nodeId = Self.nodeId(forPublicKeyHex: publicKey)
    }

    func sign(_ envelope: BejucoEnvelope) -> BejucoEnvelope {
        var unsigned = envelope
        unsigned.originPublicKey = publicKey
        unsigned.signature = nil
        guard let data = try? AndroidEnvelopeCodec.signingData(for: unsigned),
              let signature = try? privateKey.signature(for: data) else {
            return unsigned
        }
        unsigned.signature = signature.map { String(format: "%02x", $0) }.joined()
        return unsigned
    }

    func verify(_ envelope: BejucoEnvelope) -> Bool {
        guard let encodedKey = envelope.originPublicKey,
              Self.nodeId(forPublicKeyHex: encodedKey) == envelope.originId,
              let publicData = Data(hexString: encodedKey),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicData),
              let encodedSignature = envelope.signature,
              let signatureData = Data(hexString: encodedSignature),
              let signingData = try? AndroidEnvelopeCodec.signingData(for: envelope) else {
            return false
        }
        return publicKey.isValidSignature(signatureData, for: signingData)
    }

    private static func nodeId(forPublicKeyHex publicKeyHex: String) -> String {
        let digest = SHA256.hash(data: Data(publicKeyHex.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var bytes = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = bytes
    }
}
