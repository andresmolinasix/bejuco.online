package com.bitchat.android.protocol

import com.bitchat.android.util.toHexString
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import java.security.MessageDigest
import java.util.UUID

/**
 * Bejuco Protocol v1 message types. Only DISTRESS is used by the MVP; SAFE and the
 * later supply/shelter types are intentionally deferred (docs/3 §14 - out of scope
 * until the A -> B -> C milestone is proven).
 */
enum class BejucoMessageType {
    DISTRESS,
    SAFE
}

data class BejucoLocation(
    val lat: Double,
    val lon: Double,
    val accuracy: Float? = null
)

/**
 * Bejuco Protocol v1 envelope (docs/2-MAESTRO_DE_ARQUITECTURA.md §3,
 * docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md §5 "protocol/"). Deliberately free of
 * Android, BLE and persistence dependencies so it stays the shared contract for
 * Android, and later iOS/ESP32, per docs/4-REPOSITORY_TOPOLOGY.md.
 *
 * Identity is self-certifying: [originId] is derived from [originPublicKey], so any
 * node can verify [signature] without a prior handshake or shared trust with the
 * sender - it proves "this envelope came from whoever holds this key", not that the
 * key belongs to a known or trusted person. That is a deliberate MVP limitation
 * (docs/3 §5 "security/": "prevención básica de replay", not full Sybil resistance).
 *
 * messageId uses a random UUID as a placeholder unique identifier. The formal
 * Bejuco Protocol v1 spec (docs/3 §7, to live in bejuco-platform/protocol/bejuco-v1.md)
 * still has to fix the canonical id scheme, serialization and signing preimage across
 * languages before this is safe to treat as wire-stable across implementations.
 */
data class BejucoEnvelope(
    val version: Int = 1,
    val messageId: String = UUID.randomUUID().toString(),
    val eventId: String? = null,
    val type: BejucoMessageType,
    val originId: String,
    val originPublicKey: String,
    val createdAt: Long,
    val expiresAt: Long,
    val location: BejucoLocation? = null,
    val priority: String = "SOS",
    val hopCount: Int = 0,
    val hopLimit: Int = 20,
    val payload: Map<String, String> = emptyMap(),
    var signature: String? = null
) {
    /**
     * Structural checks only: protocol shape, TTL/hop bookkeeping, and that [originId]
     * is actually derived from [originPublicKey]. Does not verify [signature] - callers
     * that need cryptographic assurance must call [verifySignature] separately, since a
     * message can be structurally well-formed but forged.
     */
    fun isStructurallyValid(nowMillis: Long = System.currentTimeMillis()): Boolean {
        if (version != 1) return false
        if (messageId.isBlank()) return false
        if (originId != originIdFor(originPublicKey)) return false
        if (hopCount < 0 || hopLimit <= 0 || hopCount > hopLimit) return false
        if (expiresAt <= createdAt) return false
        if (isExpired(nowMillis)) return false
        return true
    }

    fun isExpired(nowMillis: Long = System.currentTimeMillis()): Boolean = nowMillis >= expiresAt

    /**
     * Verifies [signature] against [originPublicKey] over [signingBytes]. Only proves
     * self-consistency of the claimed identity (see class doc) - it does not mean the
     * sender is trusted or previously known.
     */
    fun verifySignature(): Boolean {
        val signatureHex = signature ?: return false
        return try {
            val publicKeyBytes = originPublicKey.hexToByteArrayOrNull() ?: return false
            val signatureBytes = signatureHex.hexToByteArrayOrNull() ?: return false
            val message = signingBytes()
            val verifier = Ed25519Signer()
            verifier.init(false, Ed25519PublicKeyParameters(publicKeyBytes, 0))
            verifier.update(message, 0, message.size)
            verifier.verifySignature(signatureBytes)
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Canonical bytes that are signed and verified: every field except [signature]
     * (obviously) and [hopCount], which is expected to change on every relay hop -
     * same reasoning as [BitchatPacket.toBinaryDataForSigning] excluding TTL.
     */
    fun signingBytes(): ByteArray =
        gson.toJson(copy(hopCount = 0, signature = null)).toByteArray(Charsets.UTF_8)

    fun toJson(): String = gson.toJson(this)

    companion object {
        private val gson: Gson = GsonBuilder().disableHtmlEscaping().create()

        fun fromJson(json: String): BejucoEnvelope = gson.fromJson(json, BejucoEnvelope::class.java)

        /** Self-certifying origin id: first 8 bytes of SHA-256(publicKeyHex), hex-encoded. */
        fun originIdFor(publicKeyHex: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(publicKeyHex.toByteArray(Charsets.UTF_8))
            return digest.take(8).toByteArray().toHexString()
        }
    }
}

internal fun String.hexToByteArrayOrNull(): ByteArray? {
    if (length % 2 != 0) return null
    return try {
        ByteArray(length / 2) { i -> ((this[i * 2].digitToInt(16) shl 4) + this[i * 2 + 1].digitToInt(16)).toByte() }
    } catch (_: NumberFormatException) {
        null
    }
}
