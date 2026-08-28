import Foundation
import zlib

/// The outer packet used by the Android BitChat mesh.
///
/// Bejuco emergency envelopes are carried as an opaque payload with type
/// `0x30`; the mesh must not interpret the JSON inside this packet.
struct BitChatPacket {
    let version: UInt8
    let type: UInt8
    let ttl: UInt8
    let timestamp: UInt64
    let senderID: Data
    let recipientID: Data?
    let payload: Data
    let signature: Data?
    let route: [Data]?

    init(
        version: UInt8 = 1,
        type: UInt8,
        ttl: UInt8,
        timestamp: UInt64,
        senderID: Data,
        recipientID: Data? = nil,
        payload: Data,
        signature: Data? = nil,
        route: [Data]? = nil
    ) {
        self.version = version
        self.type = type
        self.ttl = ttl
        self.timestamp = timestamp
        self.senderID = senderID
        self.recipientID = recipientID
        self.payload = payload
        self.signature = signature
        self.route = route
    }
}

/// Fragment payload shared by Android's FragmentManager and BitChat iOS.
struct BitChatFragment {
    static let headerSize = 13
    static let fragmentIDSize = 8

    let fragmentID: Data
    let index: Int
    let total: Int
    let originalType: UInt8
    let data: Data

    init?(payload: Data) {
        let bytes = Array(payload)
        guard bytes.count >= Self.headerSize else { return nil }
        let index = (Int(bytes[8]) << 8) | Int(bytes[9])
        let total = (Int(bytes[10]) << 8) | Int(bytes[11])
        guard total > 0, index < total else { return nil }
        self.fragmentID = Data(bytes[0..<Self.fragmentIDSize])
        self.index = index
        self.total = total
        self.originalType = bytes[12]
        self.data = Data(bytes.dropFirst(Self.headerSize))
    }

    init(fragmentID: Data, index: Int, total: Int, originalType: UInt8, data: Data) {
        self.fragmentID = fragmentID.prefix(Self.fragmentIDSize)
        self.index = index
        self.total = total
        self.originalType = originalType
        self.data = data
    }

    func encoded() -> Data {
        var result = Data(fragmentID.prefix(Self.fragmentIDSize))
        if result.count < Self.fragmentIDSize {
            result.append(Data(repeating: 0, count: Self.fragmentIDSize - result.count))
        }
        result.append(UInt8((index >> 8) & 0xff))
        result.append(UInt8(index & 0xff))
        result.append(UInt8((total >> 8) & 0xff))
        result.append(UInt8(total & 0xff))
        result.append(originalType)
        result.append(data)
        return result
    }
}

enum BitChatPacketCodec {
    static let fragmentType: UInt8 = 0x20
    static let bejucoEnvelopeType: UInt8 = 0x30
    static let broadcastRecipient = Data(repeating: 0xff, count: 8)
    static let maxPayloadLength = 10_485_760
    static let fragmentSizeThreshold = 512
    static let maxFragmentSize = 469
    static let maxFragments = 256
    static let maxActiveFragmentSets = 64
    static let maxFragmentTotalBytes = 1_048_576
    static let maxGlobalFragmentTotalBytes = 4 * 1_048_576
    static let fragmentTimeout: TimeInterval = 30

    private static let headerSizeV1 = 14
    private static let headerSizeV2 = 16
    private static let senderIDSize = 8
    private static let recipientIDSize = 8
    private static let signatureSize = 64

    static func data(fromHex hex: String) -> Data? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var result = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        return result
    }

    static func encode(_ packet: BitChatPacket, padding: Bool = false) -> Data? {
        guard packet.version == 1 || packet.version == 2,
              packet.senderID.count <= senderIDSize,
              packet.recipientID?.count ?? 0 <= recipientIDSize,
              packet.payload.count <= maxPayloadLength,
              packet.signature == nil || packet.signature?.count == signatureSize else {
            return nil
        }

        var payload = packet.payload
        var originalPayloadSize: Int?
        var compressed = false
        if shouldCompress(payload), let candidate = RawDeflate.compress(payload), candidate.count < payload.count {
            payload = candidate
            originalPayloadSize = packet.payload.count
            compressed = true
        }

        let sizeFieldBytes = compressed ? (packet.version >= 2 ? 4 : 2) : 0
        let payloadLength = payload.count + sizeFieldBytes
        guard packet.version >= 2 || payloadLength <= UInt16.max else { return nil }

        var result = Data()
        result.reserveCapacity(
            (packet.version >= 2 ? headerSizeV2 : headerSizeV1) +
            senderIDSize +
            (packet.recipientID == nil ? 0 : recipientIDSize) +
            payloadLength +
            (packet.signature == nil ? 0 : signatureSize) +
            16
        )

        result.append(packet.version)
        result.append(packet.type)
        result.append(packet.ttl)
        appendUInt64(packet.timestamp, to: &result)

        var flags: UInt8 = 0
        if packet.recipientID != nil { flags |= 0x01 }
        if packet.signature != nil { flags |= 0x02 }
        if compressed { flags |= 0x04 }
        if packet.version >= 2, !(packet.route ?? []).isEmpty { flags |= 0x08 }
        result.append(flags)

        if packet.version >= 2 {
            appendUInt32(UInt32(payloadLength), to: &result)
        } else {
            appendUInt16(UInt16(payloadLength), to: &result)
        }

        appendFixed(packet.senderID, size: senderIDSize, to: &result)
        if let recipientID = packet.recipientID {
            appendFixed(recipientID, size: recipientIDSize, to: &result)
        }

        if packet.version >= 2, let route = packet.route, !route.isEmpty {
            let count = min(route.count, 255)
            result.append(UInt8(count))
            for hop in route.prefix(count) {
                appendFixed(hop, size: senderIDSize, to: &result)
            }
        }

        if let originalPayloadSize {
            if packet.version >= 2 {
                appendUInt32(UInt32(originalPayloadSize), to: &result)
            } else {
                guard originalPayloadSize <= UInt16.max else { return nil }
                appendUInt16(UInt16(originalPayloadSize), to: &result)
            }
        }
        result.append(payload)

        if let signature = packet.signature {
            result.append(signature)
        }

        return padding ? MessagePadding.pad(result) : result
    }

    static func decode(_ data: Data) -> BitChatPacket? {
        decodeCore(data) ?? decodeCore(Data(MessagePadding.unpad(data)))
    }

    /// Prepares the same packet/fragment sequence Android sends over BLE.
    static func prepareForBLE(_ packet: BitChatPacket, maxFrameSize: Int = fragmentSizeThreshold) -> [Data]? {
        guard maxFrameSize > 0 else { return nil }
        guard let padded = encode(packet, padding: true) else { return nil }
        let fullData = MessagePadding.unpad(padded)
        let frameLimit = min(fragmentSizeThreshold, maxFrameSize)
        if fullData.count <= frameLimit {
            guard let encoded = encode(packet, padding: false), encoded.count <= frameLimit else { return nil }
            return [encoded]
        }

        // Android selects v2 whenever route is non-null, including an empty
        // route list. Keep that choice here even though an empty route does
        // not set HAS_ROUTE on the wire.
        let version: UInt8 = packet.route == nil ? 1 : 2
        let headerSize = version == 2 ? 15 : 13 // Android FragmentManager's sizing rule.
        let routeSize = version == 2 ? 1 + min(packet.route?.count ?? 0, 255) * senderIDSize : 0
        let recipientSize = packet.recipientID == nil ? 0 : recipientIDSize
        let overhead = headerSize + senderIDSize + recipientSize + routeSize + BitChatFragment.headerSize + 16
        let maxDataSize = min(maxFragmentSize, frameLimit - overhead)
        guard maxDataSize > 0 else { return nil }

        let total = Int(ceil(Double(fullData.count) / Double(maxDataSize)))
        guard total > 0, total <= maxFragments else { return nil }
        var fragmentID = Data(count: BitChatFragment.fragmentIDSize)
        fragmentID.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for index in 0..<BitChatFragment.fragmentIDSize {
                buffer[index] = UInt8.random(in: 0...UInt8.max)
            }
        }

        var frames: [Data] = []
        frames.reserveCapacity(total)
        for index in 0..<total {
            let start = index * maxDataSize
            let end = min(start + maxDataSize, fullData.count)
            let fragmentPayload = BitChatFragment(
                fragmentID: fragmentID,
                index: index,
                total: total,
                originalType: packet.type,
                data: Data(fullData[start..<end])
            )
            let fragmentPacket = BitChatPacket(
                version: version,
                type: fragmentType,
                ttl: packet.ttl,
                timestamp: packet.timestamp,
                senderID: packet.senderID,
                recipientID: packet.recipientID,
                payload: fragmentPayload.encoded(),
                signature: nil,
                route: packet.route
            )
            guard let encoded = encode(fragmentPacket, padding: false) else { return nil }
            frames.append(encoded)
        }
        return frames
    }

    private static func decodeCore(_ data: Data) -> BitChatPacket? {
        let bytes = Array(data)
        guard bytes.count >= headerSizeV1 + senderIDSize else { return nil }
        let version = bytes[0]
        guard version == 1 || version == 2 else { return nil }

        let headerSize = version == 2 ? headerSizeV2 : headerSizeV1
        let type = bytes[1]
        let ttl = bytes[2]
        guard let timestamp = readUInt64(bytes, at: 3) else { return nil }
        let flags = bytes[11]
        let hasRecipient = flags & 0x01 != 0
        let hasSignature = flags & 0x02 != 0
        let compressed = flags & 0x04 != 0
        let hasRoute = version == 2 && flags & 0x08 != 0
        let payloadLength: Int
        if version == 2 {
            guard let length = readUInt32(bytes, at: 12), length <= UInt32(maxPayloadLength) else { return nil }
            payloadLength = Int(length)
        } else {
            guard let length = readUInt16(bytes, at: 12) else { return nil }
            payloadLength = length
        }

        var offset = headerSize
        guard let senderID = readFixed(bytes, at: offset, size: senderIDSize) else { return nil }
        offset += senderIDSize

        var recipientID: Data?
        if hasRecipient {
            guard let recipient = readFixed(bytes, at: offset, size: recipientIDSize) else { return nil }
            recipientID = recipient
            offset += recipientIDSize
        }

        var route: [Data]?
        if hasRoute {
            guard offset < bytes.count else { return nil }
            let count = Int(bytes[offset])
            offset += 1
            let routeSize = count.multipliedReportingOverflow(by: senderIDSize)
            guard !routeSize.overflow else { return nil }
            let routeBytes = routeSize.partialValue
            guard offset + routeBytes <= bytes.count else { return nil }
            var hops: [Data] = []
            hops.reserveCapacity(count)
            for _ in 0..<count {
                guard let hop = readFixed(bytes, at: offset, size: senderIDSize) else { return nil }
                hops.append(hop)
                offset += senderIDSize
            }
            route = hops.isEmpty ? nil : hops
        }

        guard payloadLength <= maxPayloadLength, offset + payloadLength <= bytes.count else { return nil }
        let payloadBytes = Array(bytes[offset..<(offset + payloadLength)])
        offset += payloadLength

        var payload: Data
        if compressed {
            let lengthFieldBytes = version == 2 ? 4 : 2
            guard payloadBytes.count >= lengthFieldBytes else { return nil }
            let originalSize: Int
            if version == 2 {
                guard let value = readUInt32(payloadBytes, at: 0), value > 0, value <= UInt32(maxPayloadLength) else { return nil }
                originalSize = Int(value)
            } else {
                guard let value = readUInt16(payloadBytes, at: 0), value > 0 else { return nil }
                originalSize = Int(value)
            }
            let compressedBytes = Data(payloadBytes.dropFirst(lengthFieldBytes))
            guard !compressedBytes.isEmpty,
                  Double(originalSize) / Double(compressedBytes.count) <= 50_000,
                  let expanded = RawDeflate.decompress(compressedBytes, expectedSize: originalSize) else { return nil }
            payload = expanded
        } else {
            payload = Data(payloadBytes)
        }

        var signature: Data?
        if hasSignature {
            guard offset + signatureSize <= bytes.count else { return nil }
            signature = Data(bytes[offset..<(offset + signatureSize)])
        }

        return BitChatPacket(
            version: version,
            type: type,
            ttl: ttl,
            timestamp: timestamp,
            senderID: senderID,
            recipientID: recipientID,
            payload: payload,
            signature: signature,
            route: route
        )
    }

    private static func shouldCompress(_ data: Data) -> Bool {
        guard data.count >= 100 else { return false }
        let uniqueRatio = Double(Set(data).count) / Double(min(data.count, 256))
        return uniqueRatio < 0.9
    }

    private static func appendFixed(_ value: Data, size: Int, to result: inout Data) {
        result.append(value.prefix(size))
        if value.count < size {
            result.append(Data(repeating: 0, count: size - value.count))
        }
    }

    private static func appendUInt16(_ value: UInt16, to result: inout Data) {
        result.append(UInt8((value >> 8) & 0xff))
        result.append(UInt8(value & 0xff))
    }

    private static func appendUInt32(_ value: UInt32, to result: inout Data) {
        result.append(UInt8((value >> 24) & 0xff))
        result.append(UInt8((value >> 16) & 0xff))
        result.append(UInt8((value >> 8) & 0xff))
        result.append(UInt8(value & 0xff))
    }

    private static func appendUInt64(_ value: UInt64, to result: inout Data) {
        for shift in stride(from: 56, through: 0, by: -8) {
            result.append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> Int? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return UInt32(bytes[offset]) << 24 |
            UInt32(bytes[offset + 1]) << 16 |
            UInt32(bytes[offset + 2]) << 8 |
            UInt32(bytes[offset + 3])
    }

    private static func readUInt64(_ bytes: [UInt8], at offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= bytes.count else { return nil }
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(bytes[offset + index])
        }
        return value
    }

    private static func readFixed(_ bytes: [UInt8], at offset: Int, size: Int) -> Data? {
        guard offset >= 0, offset + size <= bytes.count else { return nil }
        return Data(bytes[offset..<(offset + size)])
    }
}

private enum MessagePadding {
    static func pad(_ data: Data) -> Data {
        let target: Int
        let totalSize = data.count + 16
        if totalSize <= 256 { target = 256 }
        else if totalSize <= 512 { target = 512 }
        else if totalSize <= 1024 { target = 1024 }
        else if totalSize <= 2048 { target = 2048 }
        else { target = data.count }

        let paddingLength = target - data.count
        guard paddingLength > 0, paddingLength <= 255 else { return data }
        var result = data
        result.append(Data(repeating: UInt8(paddingLength), count: paddingLength))
        return result
    }

    static func unpad(_ data: Data) -> Data {
        guard let last = data.last else { return data }
        let paddingLength = Int(last)
        guard paddingLength > 0, paddingLength <= data.count else { return data }
        guard data.suffix(paddingLength).allSatisfy({ $0 == last }) else { return data }
        return data.dropLast(paddingLength)
    }
}

private enum RawDeflate {
    static func compress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var capacity = data.count + (data.count / 16_384 + 1) * 6 + 64
        for _ in 0..<5 {
            var stream = z_stream()
            guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return nil
            }
            var output = Data(count: capacity)
            let result: Int32 = data.withUnsafeBytes { inputBuffer in
                output.withUnsafeMutableBytes { outputBuffer in
                    stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                    stream.avail_in = uInt(data.count)
                    stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(capacity)
                    return deflate(&stream, Z_FINISH)
                }
            }
            let outputCount = Int(stream.total_out)
            deflateEnd(&stream)
            if result == Z_STREAM_END {
                return Data(output.prefix(outputCount))
            }
            capacity *= 2
        }
        return nil
    }

    static func decompress(_ data: Data, expectedSize: Int) -> Data? {
        inflate(data, expectedSize: expectedSize, windowBits: -15) ??
            inflate(data, expectedSize: expectedSize, windowBits: 15)
    }

    private static func inflate(_ data: Data, expectedSize: Int, windowBits: Int32) -> Data? {
        guard !data.isEmpty, expectedSize > 0 else { return nil }
        var stream = z_stream()
        guard inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        var output = Data(count: expectedSize)
        let result: Int32 = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(data.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expectedSize)
                    return zlib.inflate(&stream, Z_FINISH)
            }
        }
        let outputCount = Int(stream.total_out)
        let remainingInput = stream.avail_in
        inflateEnd(&stream)
        guard result == Z_STREAM_END,
              outputCount == expectedSize,
              remainingInput == 0 else { return nil }
        return output
    }
}
