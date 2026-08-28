package com.bitchat.android.protocol

import org.bouncycastle.crypto.generators.Ed25519KeyPairGenerator
import org.bouncycastle.crypto.params.Ed25519KeyGenerationParameters
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.SecureRandom

/**
 * Pure protocol-level tests: no Android/Robolectric needed, since [BejucoEnvelope] has
 * no Android dependency by design (docs/3 §5: "protocol/ ... independiente de UI, BLE
 * y base de datos"). Signing here uses a throwaway BouncyCastle key pair rather than
 * crypto/EncryptionService, to keep the protocol contract testable on its own.
 */
class BejucoEnvelopeTest {

    private fun newSigningKeyPair(): Pair<Ed25519PrivateKeyParameters, String> {
        val generator = Ed25519KeyPairGenerator()
        generator.init(Ed25519KeyGenerationParameters(SecureRandom()))
        val keyPair = generator.generateKeyPair()
        val privateKey = keyPair.private as Ed25519PrivateKeyParameters
        val publicKeyHex = (keyPair.public as org.bouncycastle.crypto.params.Ed25519PublicKeyParameters)
            .encoded.toHexString()
        return privateKey to publicKeyHex
    }

    private fun sign(privateKey: Ed25519PrivateKeyParameters, data: ByteArray): String {
        val signer = Ed25519Signer()
        signer.init(true, privateKey)
        signer.update(data, 0, data.size)
        return signer.generateSignature().toHexString()
    }

    private fun distressEnvelope(publicKeyHex: String, hopCount: Int = 0): BejucoEnvelope {
        val now = System.currentTimeMillis()
        return BejucoEnvelope(
            type = BejucoMessageType.DISTRESS,
            originId = BejucoEnvelope.originIdFor(publicKeyHex),
            originPublicKey = publicKeyHex,
            createdAt = now,
            expiresAt = now + 60_000,
            location = BejucoLocation(lat = 5.69, lon = -76.66),
            hopCount = hopCount
        )
    }

    @Test
    fun `a correctly signed envelope verifies and is structurally valid`() {
        val (privateKey, publicKeyHex) = newSigningKeyPair()
        val envelope = distressEnvelope(publicKeyHex)
        envelope.signature = sign(privateKey, envelope.signingBytes())

        assertTrue(envelope.isStructurallyValid())
        assertTrue(envelope.verifySignature())
    }

    @Test
    fun `hopCount changing after signing does not break verification`() {
        // A relay increments hopCount on every hop; the signature must survive that,
        // exactly like BitchatPacket excludes TTL from its signing preimage.
        val (privateKey, publicKeyHex) = newSigningKeyPair()
        val original = distressEnvelope(publicKeyHex, hopCount = 0)
        original.signature = sign(privateKey, original.signingBytes())

        val relayed = original.copy(hopCount = original.hopCount + 1)
        relayed.signature = original.signature

        assertTrue(relayed.verifySignature())
    }

    @Test
    fun `tampering with a signed field fails verification`() {
        val (privateKey, publicKeyHex) = newSigningKeyPair()
        val envelope = distressEnvelope(publicKeyHex)
        envelope.signature = sign(privateKey, envelope.signingBytes())

        val tampered = envelope.copy(location = BejucoLocation(lat = 0.0, lon = 0.0))
        tampered.signature = envelope.signature

        assertFalse(tampered.verifySignature())
    }

    @Test
    fun `a forged originId does not verify even with a matching signature`() {
        val (privateKey, publicKeyHex) = newSigningKeyPair()
        val (_, otherPublicKeyHex) = newSigningKeyPair()
        val envelope = distressEnvelope(publicKeyHex).copy(originId = BejucoEnvelope.originIdFor(otherPublicKeyHex))
        envelope.signature = sign(privateKey, envelope.signingBytes())

        assertFalse(envelope.isStructurallyValid())
    }

    @Test
    fun `hopCount above hopLimit is structurally invalid`() {
        val (_, publicKeyHex) = newSigningKeyPair()
        val envelope = distressEnvelope(publicKeyHex, hopCount = 999)

        assertFalse(envelope.isStructurallyValid())
    }

    @Test
    fun `an expired envelope is structurally invalid`() {
        val (_, publicKeyHex) = newSigningKeyPair()
        val now = System.currentTimeMillis()
        val envelope = distressEnvelope(publicKeyHex).copy(createdAt = now - 120_000, expiresAt = now - 60_000)

        assertFalse(envelope.isStructurallyValid(nowMillis = now))
    }

    @Test
    fun `round-tripping through JSON preserves the envelope`() {
        val (privateKey, publicKeyHex) = newSigningKeyPair()
        val envelope = distressEnvelope(publicKeyHex)
        envelope.signature = sign(privateKey, envelope.signingBytes())

        val restored = BejucoEnvelope.fromJson(envelope.toJson())

        assertTrue(restored.verifySignature())
        assertTrue(restored == envelope)
    }
}
