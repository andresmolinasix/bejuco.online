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
    private let account = "p256-signing-key-v1"

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

    private let privateKey: P256.Signing.PrivateKey

    init() {
        let keychain = KeychainStore()
        let loadedKey: P256.Signing.PrivateKey

		if let stored = try? keychain.read(), let decoded = try? P256.Signing.PrivateKey(rawRepresentation: stored) {
            loadedKey = decoded
        } else {
            let generated = P256.Signing.PrivateKey()
            try? keychain.write(generated.rawRepresentation)
            loadedKey = generated
        }

        privateKey = loadedKey
        let publicData = loadedKey.publicKey.rawRepresentation
        publicKey = publicData.base64EncodedString()
        let digest = SHA256.hash(data: publicData)
        nodeId = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func sign(_ envelope: BejucoEnvelope) -> BejucoEnvelope {
        var unsigned = envelope
        unsigned.originPublicKey = publicKey
        unsigned.signature = nil
        guard let data = try? ProtocolCodec.signingData(for: unsigned),
              let signature = try? privateKey.signature(for: data) else {
            return unsigned
        }
        unsigned.signature = signature.derRepresentation.base64EncodedString()
        return unsigned
    }

    func verify(_ envelope: BejucoEnvelope) -> Bool {
        guard let encodedKey = envelope.originPublicKey,
              let publicData = Data(base64Encoded: encodedKey),
              let publicKey = try? P256.Signing.PublicKey(rawRepresentation: publicData),
              let encodedSignature = envelope.signature,
              let signatureData = Data(base64Encoded: encodedSignature),
              let signature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData),
              let signingData = try? ProtocolCodec.signingData(for: envelope) else {
            return false
        }
        return publicKey.isValidSignature(signature, for: signingData)
    }
}
