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
}

