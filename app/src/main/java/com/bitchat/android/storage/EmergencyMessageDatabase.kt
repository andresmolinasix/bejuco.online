package com.bitchat.android.storage

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Propagation lifecycle of a persisted emergency message (ADR-0003: a message is
 * never deleted just because it was sent to one peer - only expiry, protocol-level
 * invalidation, or an explicit ACK rule retires it).
 */
enum class MessagePropagationState {
    PENDING,
    EXPIRED,
    INVALID
}

data class EmergencyMessageRecord(
    val messageId: String,
    val envelopeJson: String,
    val type: String,
    val originId: String,
    val createdAt: Long,
    val expiresAt: Long,
    val hopCount: Int,
    val propagationState: MessagePropagationState,
    val receivedAt: Long
)

/**
 * SQLite-backed store for Bejuco emergency packets (ADR-0003:
 * docs/adr/0003-persistent-store-carry-forward.md). Deliberately plain
 * SQLiteOpenHelper, mirroring services/ConversationRepository.kt's proven pattern,
 * instead of Room: this repo enforces strict dependency locking and dependency
 * verification (gradle.lockfile + gradle/verification-metadata.xml), and Room's
 * runtime/KSP artifacts are not yet trusted there. Revisit if/when the project
 * decides that migration is worth touching those files for.
 *
 * Known gap: rows are stored in plaintext. `location` inside the envelope JSON is
 * sensitive by design (docs/2-MAESTRO_DE_ARQUITECTURA.md §6) - encrypting this
 * database at rest, the way ConversationDatabase does for private chats, is
 * unresolved follow-up work, not an oversight to silently ignore.
 */
internal class EmergencyMessageDatabase(
    context: Context,
    databaseName: String = DEFAULT_DATABASE_NAME
) : SQLiteOpenHelper(context.applicationContext, databaseName, null, DATABASE_VERSION) {

    companion object {
        internal const val DEFAULT_DATABASE_NAME = "emergency_messages.db"
        internal const val DATABASE_VERSION = 1

        private const val TABLE = "emergency_messages"
        private const val COL_MESSAGE_ID = "message_id"
        private const val COL_ENVELOPE_JSON = "envelope_json"
        private const val COL_TYPE = "type"
        private const val COL_ORIGIN_ID = "origin_id"
        private const val COL_CREATED_AT = "created_at"
        private const val COL_EXPIRES_AT = "expires_at"
        private const val COL_HOP_COUNT = "hop_count"
        private const val COL_PROPAGATION_STATE = "propagation_state"
        private const val COL_RECEIVED_AT = "received_at"
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
                $COL_MESSAGE_ID TEXT PRIMARY KEY NOT NULL,
                $COL_ENVELOPE_JSON TEXT NOT NULL,
                $COL_TYPE TEXT NOT NULL,
                $COL_ORIGIN_ID TEXT NOT NULL,
                $COL_CREATED_AT INTEGER NOT NULL,
                $COL_EXPIRES_AT INTEGER NOT NULL,
                $COL_HOP_COUNT INTEGER NOT NULL,
                $COL_PROPAGATION_STATE TEXT NOT NULL,
                $COL_RECEIVED_AT INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_emergency_messages_state ON $TABLE ($COL_PROPAGATION_STATE)")
        db.execSQL("CREATE INDEX idx_emergency_messages_expires_at ON $TABLE ($COL_EXPIRES_AT)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // No prior versions exist yet; first schema.
    }

    /** message_id is the primary key, so a duplicate insert is a silent no-op (dedup). */
    fun insertIgnoringDuplicates(record: EmergencyMessageRecord): Boolean {
        val values = ContentValues().apply {
            put(COL_MESSAGE_ID, record.messageId)
            put(COL_ENVELOPE_JSON, record.envelopeJson)
            put(COL_TYPE, record.type)
            put(COL_ORIGIN_ID, record.originId)
            put(COL_CREATED_AT, record.createdAt)
            put(COL_EXPIRES_AT, record.expiresAt)
            put(COL_HOP_COUNT, record.hopCount)
            put(COL_PROPAGATION_STATE, record.propagationState.name)
            put(COL_RECEIVED_AT, record.receivedAt)
        }
        val rowId = writableDatabase.insertWithOnConflict(
            TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE
        )
        return rowId != -1L
    }

    fun findById(messageId: String): EmergencyMessageRecord? {
        readableDatabase.query(
            TABLE, null, "$COL_MESSAGE_ID = ?", arrayOf(messageId), null, null, null
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.toRecord() else null
        }
    }

    /** Messages this node still has a reason to relay: neither expired nor invalid. */
    fun loadActive(): List<EmergencyMessageRecord> {
        readableDatabase.query(
            TABLE,
            null,
            "$COL_PROPAGATION_STATE = ?",
            arrayOf(MessagePropagationState.PENDING.name),
            null,
            null,
            "$COL_RECEIVED_AT ASC"
        ).use { cursor ->
            val results = mutableListOf<EmergencyMessageRecord>()
            while (cursor.moveToNext()) results.add(cursor.toRecord())
            return results
        }
    }

    /** Flips PENDING rows whose TTL has elapsed to EXPIRED. Does not delete them. */
    fun markExpired(nowMillis: Long): Int {
        val values = ContentValues().apply {
            put(COL_PROPAGATION_STATE, MessagePropagationState.EXPIRED.name)
        }
        return writableDatabase.update(
            TABLE,
            values,
            "$COL_PROPAGATION_STATE = ? AND $COL_EXPIRES_AT <= ?",
            arrayOf(MessagePropagationState.PENDING.name, nowMillis.toString())
        )
    }

    private fun Cursor.toRecord(): EmergencyMessageRecord = EmergencyMessageRecord(
        messageId = getString(getColumnIndexOrThrow(COL_MESSAGE_ID)),
        envelopeJson = getString(getColumnIndexOrThrow(COL_ENVELOPE_JSON)),
        type = getString(getColumnIndexOrThrow(COL_TYPE)),
        originId = getString(getColumnIndexOrThrow(COL_ORIGIN_ID)),
        createdAt = getLong(getColumnIndexOrThrow(COL_CREATED_AT)),
        expiresAt = getLong(getColumnIndexOrThrow(COL_EXPIRES_AT)),
        hopCount = getInt(getColumnIndexOrThrow(COL_HOP_COUNT)),
        propagationState = MessagePropagationState.valueOf(getString(getColumnIndexOrThrow(COL_PROPAGATION_STATE))),
        receivedAt = getLong(getColumnIndexOrThrow(COL_RECEIVED_AT))
    )
}
