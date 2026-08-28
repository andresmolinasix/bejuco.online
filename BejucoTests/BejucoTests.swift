import XCTest
@testable import Bejuco

@MainActor
final class BejucoTests: XCTestCase {
    func testEnvelopeUsesStableProtocolShapeAndRelayBudget() throws {
        let envelope = BejucoEnvelope(
            eventId: "quake-001",
            type: .distress,
            originId: "node-a",
            location: GeoLocation(lat: 5.69, lon: -76.66, accuracy: 12),
            priority: .critical,
            hopLimit: 2,
            payload: ["name": "Ana", "phone": "3000000000"]
        )

        let data = try ProtocolCodec.encode(envelope)
        let decoded = try ProtocolCodec.decode(BejucoEnvelope.self, from: data)

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(envelope.relayed().hopCount, 1)
        XCTAssertFalse(envelope.relayed().relayed().relayed().canRelay)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("messageId") == true)
    }

    func testIdentitySignsAndVerifiesEnvelopeIncludingRelays() {
        let identity = IdentityService()
        let envelope = BejucoEnvelope(
            type: .safe,
            originId: identity.nodeId,
            location: nil,
            priority: .normal,
            payload: ["name": "Ana"]
        )

        let signed = identity.sign(envelope)
        XCTAssertNotNil(signed.signature)
        XCTAssertTrue(identity.verify(signed))
        XCTAssertTrue(identity.verify(signed.relayed()))
    }

    func testMessageStoreDeduplicatesByMessageId() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bejuco-test-\(UUID().uuidString).json")
        let store = MessageStore(fileURL: url)
        let envelope = BejucoEnvelope(
            messageId: "same-message",
            type: .distress,
            originId: "node-a",
            location: nil,
            priority: .critical
        )

        XCTAssertTrue(store.insert(envelope))
        XCTAssertFalse(store.insert(envelope.relayed()))
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.envelope.messageId, "same-message")

        try? FileManager.default.removeItem(at: url)
    }

    func testAndroidEnvelopeUsesHexEd25519WireShape() throws {
        let identity = IdentityService()
        let envelope = BejucoEnvelope(
            eventId: nil,
            type: .distress,
            originId: identity.nodeId,
            location: GeoLocation(lat: 5.69, lon: -76.66, accuracy: 12),
            priority: .sos,
            payload: ["z": "último", "a": "Ana"]
        )

        let signed = identity.sign(envelope)
        let data = try AndroidEnvelopeCodec.encode(signed)
        let json = String(data: data, encoding: .utf8) ?? ""
        let decoded = try AndroidEnvelopeCodec.decode(data)

        XCTAssertEqual(decoded, signed)
        XCTAssertEqual(signed.originPublicKey?.count, 64)
        XCTAssertEqual(signed.signature?.count, 128)
        XCTAssertTrue(json.contains("\"type\":\"DISTRESS\""))
        XCTAssertTrue(json.contains("\"priority\":\"SOS\""))
        XCTAssertTrue(identity.verify(signed))
    }

    func testBitChatPacketRoundTripsCompressedPayloadAndPadding() throws {
        let payload = Data(repeating: 0x41, count: 1_200)
        let packet = BitChatPacket(
            type: BitChatPacketCodec.bejucoEnvelopeType,
            ttl: 7,
            timestamp: 1_735_000_123_456,
            senderID: Data([1, 2, 3, 4, 5, 6, 7, 8]),
            recipientID: BitChatPacketCodec.broadcastRecipient,
            payload: payload,
            signature: Data(repeating: 0xAB, count: 64)
        )

        let encoded = try XCTUnwrap(BitChatPacketCodec.encode(packet, padding: true))
        let decoded = try XCTUnwrap(BitChatPacketCodec.decode(encoded))

        XCTAssertEqual(decoded.version, packet.version)
        XCTAssertEqual(decoded.type, packet.type)
        XCTAssertEqual(decoded.ttl, packet.ttl)
        XCTAssertEqual(decoded.timestamp, packet.timestamp)
        XCTAssertEqual(decoded.senderID, packet.senderID)
        XCTAssertEqual(decoded.recipientID, packet.recipientID)
        XCTAssertEqual(decoded.payload, packet.payload)
        XCTAssertEqual(decoded.signature, packet.signature)
    }

    func testBitChatFragmentsReassembleOriginalPacket() throws {
        let payload = Data((0..<1_024).map { UInt8($0 % 256) })
        let packet = BitChatPacket(
            type: BitChatPacketCodec.bejucoEnvelopeType,
            ttl: 7,
            timestamp: 1_735_000_123_456,
            senderID: Data([1, 2, 3, 4, 5, 6, 7, 8]),
            recipientID: BitChatPacketCodec.broadcastRecipient,
            payload: payload
        )

        let frames = try XCTUnwrap(BitChatPacketCodec.prepareForBLE(packet))
        XCTAssertGreaterThan(frames.count, 1)

        let fragments = try frames.map { frame -> BitChatFragment in
            let fragmentPacket = try XCTUnwrap(BitChatPacketCodec.decode(frame))
            return try XCTUnwrap(BitChatFragment(payload: fragmentPacket.payload))
        }
        let assembled = fragments
            .sorted { $0.index < $1.index }
            .reduce(into: Data()) { result, fragment in result.append(fragment.data) }
        let restored = try XCTUnwrap(BitChatPacketCodec.decode(assembled))

        XCTAssertEqual(restored.type, packet.type)
        XCTAssertEqual(restored.payload, packet.payload)
        XCTAssertEqual(fragments.map(\.total).first, fragments.count)
    }

    func testBitChatFragmentsRespectNegotiatedBLELimit() throws {
        let payload = Data((0..<1_800).map { UInt8(($0 * 37 + 11) % 251) })
        let packet = BitChatPacket(
            type: BitChatPacketCodec.bejucoEnvelopeType,
            ttl: 7,
            timestamp: 1_735_000_123_456,
            senderID: Data([1, 2, 3, 4, 5, 6, 7, 8]),
            recipientID: BitChatPacketCodec.broadcastRecipient,
            payload: payload
        )

        let frames = try XCTUnwrap(BitChatPacketCodec.prepareForBLE(packet, maxFrameSize: 182))
        XCTAssertGreaterThan(frames.count, 1)
        XCTAssertTrue(frames.allSatisfy { $0.count <= 182 })

        let fragments = try frames.map { frame -> BitChatFragment in
            let fragmentPacket = try XCTUnwrap(BitChatPacketCodec.decode(frame))
            return try XCTUnwrap(BitChatFragment(payload: fragmentPacket.payload))
        }
        let assembled = fragments
            .sorted { $0.index < $1.index }
            .reduce(into: Data()) { result, fragment in result.append(fragment.data) }
        let restored = try XCTUnwrap(BitChatPacketCodec.decode(assembled))

        XCTAssertEqual(restored.payload, packet.payload)
    }
}
