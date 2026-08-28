package com.bitchat.android.emergency

import android.content.Context
import com.bitchat.android.protocol.BejucoEnvelope
import com.bitchat.android.protocol.BejucoLocation
import com.bitchat.android.protocol.BejucoMessageType
import com.bitchat.android.storage.EmergencyMessageDatabase
import com.bitchat.android.storage.EmergencyMessageRecord
import com.bitchat.android.storage.MessagePropagationState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Persistence and validation boundary for Bejuco emergency packets (ADR-0003:
 * docs/adr/0003-persistent-store-carry-forward.md).
 *
 * This is the *only* place that knows a [BejucoEnvelope] exists. The BLE mesh layer
 * (`mesh/`) transports opaque bytes and must never import this class or
 * [BejucoEnvelope] directly (docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md §5:
 * "El módulo `mesh` no debe interpretar que un paquete significa 'SOS'..."). Wiring a
 * relay above `mesh/` that decodes wire bytes and calls [receiveEnvelope] - and that
 * reads [activeMessages] to decide what to (re)send - is the next step and is
 * deliberately not part of this change.
 *
 * SQLite (via [EmergencyMessageDatabase]) is the sole source of truth. There is no
 * in-memory cache here: every read goes to disk. That trades a small amount of
 * latency for the one property this class exists to guarantee - a message survives
 * process death, app close and device reboot - which an in-memory cache cannot do by
 * definition.
 */
class EmergencyMessageRepository internal constructor(
    private val database: EmergencyMessageDatabase
) {
    companion object {
        const val DEFAULT_DISTRESS_TTL_MS = 24L * 60 * 60 * 1000 // 24h; revisit once Bejuco Protocol v1 fixes TTL semantics.
        const val DEFAULT_HOP_LIMIT = 20

        @Volatile
        private var instance: EmergencyMessageRepository? = null

        fun getInstance(context: Context): EmergencyMessageRepository =
            instance ?: synchronized(this) {
                instance ?: EmergencyMessageRepository(
                    EmergencyMessageDatabase(context.applicationContext)
                ).also { instance = it }
            }
    }

    /**
     * Builds an unsigned DISTRESS envelope originated by this device. Signing is the
     * caller's responsibility (e.g. via crypto/EncryptionService.signData on
     * [BejucoEnvelope.signingBytes]) - this class intentionally does not depend on the
     * app's identity/crypto singleton, to keep persistence and signing independently
     * testable and swappable.
     */
    fun buildDistressEnvelope(
        originPublicKeyHex: String,
        location: BejucoLocation?,
        eventId: String? = null,
        payload: Map<String, String> = emptyMap(),
        ttlMillis: Long = DEFAULT_DISTRESS_TTL_MS,
        hopLimit: Int = DEFAULT_HOP_LIMIT,
        nowMillis: Long = System.currentTimeMillis()
    ): BejucoEnvelope = BejucoEnvelope(
        eventId = eventId,
        type = BejucoMessageType.DISTRESS,
        originId = BejucoEnvelope.originIdFor(originPublicKeyHex),
        originPublicKey = originPublicKeyHex,
        createdAt = nowMillis,
        expiresAt = nowMillis + ttlMillis,
        location = location,
        hopLimit = hopLimit,
        payload = payload
    )

    /**
     * Validates and persists an envelope - self-originated and already signed, or
     * received from the mesh. Rejects anything structurally invalid, expired, or whose
     * signature does not match its own claimed [BejucoEnvelope.originPublicKey].
     *
     * Returns true if the envelope is now known to this node (freshly stored or a
     * duplicate already present) - never returns false for a duplicate, since a
     * duplicate is not a rejection.
     */
    suspend fun receiveEnvelope(
        envelope: BejucoEnvelope,
        nowMillis: Long = System.currentTimeMillis()
    ): Boolean {
        if (!envelope.isStructurallyValid(nowMillis)) return false
        if (!envelope.verifySignature()) return false

        val record = EmergencyMessageRecord(
            messageId = envelope.messageId,
            envelopeJson = envelope.toJson(),
            type = envelope.type.name,
            originId = envelope.originId,
            createdAt = envelope.createdAt,
            expiresAt = envelope.expiresAt,
            hopCount = envelope.hopCount,
            propagationState = MessagePropagationState.PENDING,
            receivedAt = nowMillis
        )
        withContext(Dispatchers.IO) {
            // message_id is the primary key: a peer relaying the same packet through a
            // different path is a no-op here, not a duplicate emergency (ADR-0003).
            database.insertIgnoringDuplicates(record)
        }
        return true
    }

    /** Messages this node still has a reason to relay: not expired, not invalidated. */
    suspend fun activeMessages(): List<BejucoEnvelope> = withContext(Dispatchers.IO) {
        database.loadActive().mapNotNull { record ->
            runCatching { BejucoEnvelope.fromJson(record.envelopeJson) }.getOrNull()
        }
    }

    /** Flips PENDING rows whose TTL has elapsed to EXPIRED. Rows are kept, not deleted. */
    suspend fun expireStaleMessages(nowMillis: Long = System.currentTimeMillis()): Int =
        withContext(Dispatchers.IO) { database.markExpired(nowMillis) }
}
