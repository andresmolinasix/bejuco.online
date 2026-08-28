package com.bitchat.android.mesh

/**
 * The only thing `mesh/` knows about Bejuco emergency packets: that a
 * BEJUCO_ENVELOPE-tagged packet exists and someone outside this package wants its
 * raw bytes. Deliberately does not reference `protocol.BejucoEnvelope` or
 * `emergency.EmergencyMessageRepository` - decoding, validation and persistence all
 * live in `emergency/`, per docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md §5
 * ("El módulo `mesh` no debe interpretar que un paquete significa 'SOS'...").
 */
interface EmergencyPacketSink {
    fun onEmergencyEnvelopeReceived(payload: ByteArray, fromPeerID: String)
}
