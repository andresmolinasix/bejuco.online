import Foundation

enum MeshFrameKind: String, Codable {
    case hello
    case request
    case packetChunk = "packet_chunk"
}

struct MeshControlFrame: Codable {
    let kind: MeshFrameKind
    let senderId: String
    let protocolVersion: Int
    let messageIds: [String]
    let requestIds: [String]
    let pageIndex: Int
    let pageCount: Int

    static func hello(senderId: String, messageIds: [String], pageIndex: Int, pageCount: Int) -> MeshControlFrame {
        MeshControlFrame(
            kind: .hello,
            senderId: senderId,
            protocolVersion: BejucoEnvelope.protocolVersion,
            messageIds: messageIds,
            requestIds: [],
            pageIndex: pageIndex,
            pageCount: pageCount
        )
    }

    static func request(senderId: String, messageIds: [String]) -> MeshControlFrame {
        MeshControlFrame(
            kind: .request,
            senderId: senderId,
            protocolVersion: BejucoEnvelope.protocolVersion,
            messageIds: [],
            requestIds: messageIds,
            pageIndex: 0,
            pageCount: 1
        )
    }
}

struct MeshTransferFrame: Codable {
    let kind: MeshFrameKind
    let senderId: String
    let protocolVersion: Int
    let transferId: String
    let chunkIndex: Int
    let totalChunks: Int
    let chunk: String
}

