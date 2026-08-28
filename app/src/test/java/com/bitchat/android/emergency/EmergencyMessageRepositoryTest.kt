package com.bitchat.android.emergency

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.bitchat.android.protocol.BejucoEnvelope
import com.bitchat.android.protocol.BejucoLocation
import kotlinx.coroutines.test.runTest
import org.bouncycastle.crypto.generators.Ed25519KeyPairGenerator
import org.bouncycastle.crypto.params.Ed25519KeyGenerationParameters
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.SecureRandom

/**
 * Exercises the persistence guarantees ADR-0003 exists for: a message stored once is
 * still there on a fresh repository instance pointed at the same on-disk database
 * (the closest a JVM unit test gets to proving survival across process death), and
 * duplicate delivery never produces two rows for the same messageId
 * (docs/3 §13: "[ ] deduplicación de M1", "[ ] múltiples copias no crean múltiples mensajes").
 */
@RunWith(RobolectricTestRunner::class)
class EmergencyMessageRepositoryTest {

    private lateinit var context: Context
    private lateinit var privateKey: Ed25519PrivateKeyParameters
    private lateinit var publicKeyHex: String

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        val generator = Ed25519KeyPairGenerator()
        generator.init(Ed25519KeyGenerationParameters(SecureRandom()))
        val keyPair = generator.generateKeyPair()
        privateKey = keyPair.private as Ed25519PrivateKeyParameters
        publicKeyHex = (keyPair.public as Ed25519PublicKeyParameters).encoded.toHexString()
        context.deleteDatabase("emergency_messages_test.db")
    }

    private fun signed(repository: EmergencyMessageRepository, location: BejucoLocation): BejucoEnvelope {
        val envelope = repository.buildDistressEnvelope(originPublicKeyHex = publicKeyHex, location = location)
        val signer = Ed25519Signer()
        signer.init(true, privateKey)
        val bytes = envelope.signingBytes()
        signer.update(bytes, 0, bytes.size)
        envelope.signature = signer.generateSignature().toHexString()
        return envelope
    }

    private fun newRepository(): EmergencyMessageRepository = EmergencyMessageRepository(
        com.bitchat.android.storage.EmergencyMessageDatabase(context, "emergency_messages_test.db")
    )

    @Test
    fun `a stored distress message survives a fresh repository instance`() = runTest {
        val writer = newRepository()
        val envelope = signed(writer, BejucoLocation(lat = 5.69, lon = -76.66))

        assertTrue(writer.receiveEnvelope(envelope))

        // A new instance backed by the same database file stands in for "the process
        // died and the app/service restarted" - nothing here is shared in memory.
        val reader = newRepository()
        val active = reader.activeMessages()

        assertEquals(1, active.size)
        assertEquals(envelope.messageId, active.single().messageId)
    }

    @Test
    fun `receiving the same messageId twice does not create a second row`() = runTest {
        val repository = newRepository()
        val envelope = signed(repository, BejucoLocation(lat = 5.69, lon = -76.66))

        assertTrue(repository.receiveEnvelope(envelope))
        // Simulates the same DISTRESS arriving via a second peer/path (B and C both
        // relaying to the same node) - must dedupe on messageId, not double-store.
        assertTrue(repository.receiveEnvelope(envelope))

        assertEquals(1, repository.activeMessages().size)
    }

    @Test
    fun `an expired message drops out of activeMessages without being deleted`() = runTest {
        val repository = newRepository()
        val now = System.currentTimeMillis()
        val envelope = repository.buildDistressEnvelope(
            originPublicKeyHex = publicKeyHex,
            location = null,
            ttlMillis = 1_000,
            nowMillis = now
        )
        val signer = Ed25519Signer()
        signer.init(true, privateKey)
        val bytes = envelope.signingBytes()
        signer.update(bytes, 0, bytes.size)
        envelope.signature = signer.generateSignature().toHexString()

        // Received while still within its TTL (expiresAt = now + 1_000).
        assertTrue(repository.receiveEnvelope(envelope, nowMillis = now))
        assertEquals(1, repository.activeMessages().size)

        // Time passes past expiresAt; expireStaleMessages() is what a periodic sweep
        // (foreground service tick) would call - receiveEnvelope() itself never expires
        // rows, since it only validates freshly arriving packets.
        repository.expireStaleMessages(nowMillis = now + 2_000)

        assertEquals(0, repository.activeMessages().size)
    }
}
