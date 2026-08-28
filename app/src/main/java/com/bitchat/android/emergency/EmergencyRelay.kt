package com.bitchat.android.emergency

import android.content.Context
import android.util.Log
import com.bitchat.android.crypto.EncryptionService
import com.bitchat.android.mesh.BluetoothMeshService
import com.bitchat.android.mesh.EmergencyPacketSink
import com.bitchat.android.protocol.BejucoEnvelope
import com.bitchat.android.protocol.BejucoLocation
import com.bitchat.android.util.toHexString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * The one class that knows both `mesh/` and Bejuco's emergency domain
 * (docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md §5). Everything downstream of
 * BLE bytes - decoding, signature verification, persistence - happens here or in
 * [EmergencyMessageRepository], never inside `mesh/` itself.
 *
 * Not a singleton: its lifecycle is tied 1:1 to the [BluetoothMeshService] instance
 * it is attached to (see service/MeshServiceHolder.kt), so a replaced mesh instance
 * gets a fresh relay rather than a stale delegate reference.
 */
class EmergencyRelay(
    context: Context,
    private val meshService: BluetoothMeshService,
    private val repository: EmergencyMessageRepository = EmergencyMessageRepository.getInstance(context),
    private val encryptionService: EncryptionService = EncryptionService(context)
) : EmergencyPacketSink {

    companion object {
        private const val TAG = "EmergencyRelay"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Attaches this relay as the mesh's only route to emergency packets. */
    fun attach() {
        meshService.emergencyDelegate = this
    }

    override fun onEmergencyEnvelopeReceived(payload: ByteArray, fromPeerID: String) {
        scope.launch {
            val envelope = try {
                BejucoEnvelope.fromJson(String(payload, Charsets.UTF_8))
            } catch (e: Exception) {
                Log.w(TAG, "Discarding unparseable envelope from $fromPeerID: ${e.message}")
                return@launch
            }
            val accepted = repository.receiveEnvelope(envelope)
            if (!accepted) {
                Log.w(TAG, "Rejected envelope ${envelope.messageId} from $fromPeerID (invalid or forged)")
            }
        }
    }

    /**
     * Builds, signs, persists locally, and broadcasts a DISTRESS envelope originated by
     * this device. Persisting before broadcasting matters: per docs/3 §12 the message
     * must survive in this node ("A genera M1 -> M1 se guarda en Room") independently
     * of whether the broadcast reaches anyone.
     */
    fun sendDistress(
        location: BejucoLocation?,
        eventId: String? = null,
        payload: Map<String, String> = emptyMap()
    ) {
        scope.launch {
            val signingPublicKey = encryptionService.getSigningPublicKey()
            if (signingPublicKey == null || signingPublicKey.isEmpty()) {
                Log.e(TAG, "No signing public key available; cannot originate a DISTRESS envelope")
                return@launch
            }
            val publicKeyHex = signingPublicKey.toHexString()
            val unsigned = repository.buildDistressEnvelope(
                originPublicKeyHex = publicKeyHex,
                location = location,
                eventId = eventId,
                payload = payload
            )
            val signatureBytes = encryptionService.signData(unsigned.signingBytes())
            if (signatureBytes == null) {
                Log.e(TAG, "Failed to sign DISTRESS envelope ${unsigned.messageId}")
                return@launch
            }
            unsigned.signature = signatureBytes.toHexString()

            if (!repository.receiveEnvelope(unsigned)) {
                Log.e(TAG, "Freshly signed DISTRESS envelope ${unsigned.messageId} failed its own validation")
                return@launch
            }
            meshService.sendEmergencyEnvelope(unsigned.toJson().toByteArray(Charsets.UTF_8))
        }
    }
}
