import CoreBluetooth
import Foundation
import SwiftUI

enum MeshRuntimeState: String {
    case starting
    case active
    case bluetoothOff
    case unauthorized
    case unsupported

    var title: String {
        switch self {
        case .starting: return "Iniciando mesh"
        case .active: return "Mesh activo"
        case .bluetoothOff: return "Bluetooth apagado"
        case .unauthorized: return "Bluetooth sin permiso"
        case .unsupported: return "Bluetooth no disponible"
        }
    }
}

enum BejucoBLE {
    // Legacy native iOS transport kept for backwards-compatible iOS↔iOS
    // testing while the Android-compatible transport is rolled out.
    static let service = CBUUID(string: "A7E10000-7B5A-4D3E-9A11-0B7A00000001")
    static let control = CBUUID(string: "A7E10001-7B5A-4D3E-9A11-0B7A00000001")
    static let transfer = CBUUID(string: "A7E10002-7B5A-4D3E-9A11-0B7A00000001")

    // BitChat/Android mesh contract.
    static let bitChatService = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C")
    static let bitChatPacket = CBUUID(string: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
}

@MainActor
final class MeshService: NSObject, ObservableObject {
    @Published private(set) var state: MeshRuntimeState = .starting
    @Published private(set) var discoveredPeerCount = 0
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var lastEvent = "Inicializando Bluetooth…"

    let nodeId: String

    var messageProvider: (() -> [BejucoEnvelope])?
    var onEnvelopeReceived: ((BejucoEnvelope) -> Void)?

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var advertisedService: CBMutableService?
    private var controlCharacteristic: CBMutableCharacteristic?
    private var transferCharacteristic: CBMutableCharacteristic?
    private var bitChatService: CBMutableService?
    private var bitChatPacketCharacteristic: CBMutableCharacteristic?

    private var peripherals: [UUID: CBPeripheral] = [:]
    private var controlCharacteristics: [UUID: CBCharacteristic] = [:]
    private var transferCharacteristics: [UUID: CBCharacteristic] = [:]
    private var bitChatPacketCharacteristics: [UUID: CBCharacteristic] = [:]
    private var connectedPeripheralIDs = Set<UUID>()
    private var subscribedCentrals: [UUID: CBCentral] = [:]
    private var subscribedBitChatCentrals: [UUID: CBCentral] = [:]
    private var inventoryPages: [UUID: InventoryAssembly] = [:]
    private var transferBuffers: [UUID: [String: TransferAssembly]] = [:]
    private var bitChatFragmentBuffers: [UUID: [String: BitChatFragmentAssembly]] = [:]
    private var pendingWrites: [UUID: [PendingWrite]] = [:]
    private var activeWrites = Set<UUID>()
    private var pendingNotifications: [UUID: [PendingNotification]] = [:]

    init(nodeId: String) {
        self.nodeId = nodeId
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "online.bejuco.ios.central"]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [CBPeripheralManagerOptionRestoreIdentifierKey: "online.bejuco.ios.peripheral"]
        )
    }

    func start() {
        guard centralManager != nil, peripheralManager != nil else { return }
        updateRuntimeState()
        if centralManager.state == .poweredOn { startScanning() }
        if peripheralManager.state == .poweredOn { configurePeripheral() }
    }

    func announceLocalInventory() {
        for peerID in connectedPeripheralIDs {
            sendHello(to: peerID)
            sendStoredBitChatMessages(to: peerID)
        }
        for peerID in subscribedCentrals.keys {
            sendHello(to: peerID)
        }
        for peerID in subscribedBitChatCentrals.keys {
            sendStoredBitChatMessages(to: peerID)
        }
    }

    private func updateRuntimeState() {
        switch (centralManager.state, peripheralManager.state) {
        case (.unauthorized, _), (_, .unauthorized): state = .unauthorized
        case (.unsupported, _), (_, .unsupported): state = .unsupported
        case (.poweredOff, _), (_, .poweredOff): state = .bluetoothOff
        case (.poweredOn, .poweredOn): state = .active
        default: state = .starting
        }
    }

    private func resetBluetoothPeerState() {
        if peripheralManager?.state == .poweredOn {
            peripheralManager.stopAdvertising()
            peripheralManager.removeAllServices()
        }
        connectedPeripheralIDs.removeAll()
        controlCharacteristics.removeAll()
        transferCharacteristics.removeAll()
        bitChatPacketCharacteristics.removeAll()
        pendingWrites.removeAll()
        activeWrites.removeAll()
        inventoryPages.removeAll()
        transferBuffers.removeAll()
        bitChatFragmentBuffers.removeAll()
        subscribedCentrals.removeAll()
        subscribedBitChatCentrals.removeAll()
        pendingNotifications.removeAll()
        advertisedService = nil
        controlCharacteristic = nil
        transferCharacteristic = nil
        bitChatService = nil
        bitChatPacketCharacteristic = nil
        connectedPeerCount = 0
    }

    private func updateConnectedPeerCount() {
        var peers = connectedPeripheralIDs
        peers.formUnion(subscribedCentrals.keys)
        peers.formUnion(subscribedBitChatCentrals.keys)
        connectedPeerCount = peers.count
    }

    private func startScanning() {
        centralManager.scanForPeripherals(
            withServices: [BejucoBLE.service, BejucoBLE.bitChatService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        lastEvent = "Buscando nodos cercanos…"
    }

    private func configurePeripheral() {
        guard advertisedService == nil, bitChatService == nil else { return }

        let control = CBMutableCharacteristic(
            type: BejucoBLE.control,
            properties: [.read, .write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let transfer = CBMutableCharacteristic(
            type: BejucoBLE.transfer,
            properties: [.write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: BejucoBLE.service, primary: true)
        service.characteristics = [control, transfer]
        advertisedService = service
        controlCharacteristic = control
        transferCharacteristic = transfer
        peripheralManager.add(service)

        let bitChatPacket = CBMutableCharacteristic(
            type: BejucoBLE.bitChatPacket,
            properties: [.write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.writeable]
        )
        let bitChatService = CBMutableService(type: BejucoBLE.bitChatService, primary: true)
        bitChatService.characteristics = [bitChatPacket]
        self.bitChatService = bitChatService
        bitChatPacketCharacteristic = bitChatPacket
        peripheralManager.add(bitChatService)

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BejucoBLE.service, BejucoBLE.bitChatService],
            CBAdvertisementDataLocalNameKey: "Bejuco-\(nodeId.prefix(6))"
        ])
        lastEvent = "Anunciando y escuchando nodos"
    }

    private func sendHello(to peerID: UUID) {
        let ids = (messageProvider?() ?? []).map(\.messageId)
        // Keep control frames comfortably below the smallest negotiated BLE
        // ATT payload. Efficiency is less important than reliable discovery.
        let pageSize = 1
        let pageCount = max(1, Int(ceil(Double(max(1, ids.count)) / Double(pageSize))))

        if ids.isEmpty {
            sendControl(.hello(senderId: nodeId, messageIds: [], pageIndex: 0, pageCount: 1), to: peerID)
            return
        }

        for pageIndex in 0..<pageCount {
            let start = pageIndex * pageSize
            let end = min(start + pageSize, ids.count)
            sendControl(
                .hello(senderId: nodeId, messageIds: Array(ids[start..<end]), pageIndex: pageIndex, pageCount: pageCount),
                to: peerID
            )
        }
    }

    private func synchronize(peerID: UUID, remoteIDs: Set<String>) {
        let localMessages = messageProvider?() ?? []
        let localIDs = Set(localMessages.map(\.messageId))

        let toRequest = Array(remoteIDs.subtracting(localIDs))
        for batch in toRequest.chunked(into: 1) {
            sendControl(.request(senderId: nodeId, messageIds: batch), to: peerID)
        }

        let toSend = localMessages.filter { remoteIDs.contains($0.messageId) == false && $0.canRelay }
        for envelope in toSend {
            sendEnvelope(envelope, to: peerID)
        }
    }

    private func handleControl(_ data: Data, from peerID: UUID) {
        guard let frame = try? ProtocolCodec.decode(MeshControlFrame.self, from: data),
              frame.protocolVersion <= BejucoEnvelope.protocolVersion else { return }

        switch frame.kind {
        case .hello:
            var assembly = inventoryPages[peerID] ?? InventoryAssembly(pageCount: frame.pageCount, pages: [:])
            assembly.pageCount = frame.pageCount
            assembly.pages[frame.pageIndex] = frame.messageIds
            inventoryPages[peerID] = assembly
            if assembly.pages.count >= assembly.pageCount {
                let ids = Set(assembly.pages.values.flatMap { $0 })
                inventoryPages[peerID] = nil
                synchronize(peerID: peerID, remoteIDs: ids)
                lastEvent = "Inventario sincronizado con un nodo"
            }
        case .request:
            let requested = Set(frame.requestIds)
            for envelope in (messageProvider?() ?? []) where requested.contains(envelope.messageId) && envelope.canRelay {
                sendEnvelope(envelope, to: peerID)
            }
        case .packetChunk:
            break
        }
    }

    private func handleTransfer(_ data: Data, from peerID: UUID) {
        guard let frame = try? ProtocolCodec.decode(MeshTransferFrame.self, from: data),
              frame.protocolVersion <= BejucoEnvelope.protocolVersion,
              frame.totalChunks > 0,
              frame.chunkIndex >= 0,
              frame.chunkIndex < frame.totalChunks else { return }

        var peerTransfers = transferBuffers[peerID] ?? [:]
        var transfer = peerTransfers[frame.transferId] ?? TransferAssembly(totalChunks: frame.totalChunks, chunks: [:])
        transfer.chunks[frame.chunkIndex] = frame.chunk
        peerTransfers[frame.transferId] = transfer
        transferBuffers[peerID] = peerTransfers

        guard transfer.chunks.count >= transfer.totalChunks else { return }
        let encoded = (0..<transfer.totalChunks).compactMap { transfer.chunks[$0] }.joined()
        peerTransfers[frame.transferId] = nil
        transferBuffers[peerID] = peerTransfers

        guard let packetData = Data(base64Encoded: encoded),
              let envelope = try? ProtocolCodec.decode(BejucoEnvelope.self, from: packetData),
              envelope.version <= BejucoEnvelope.protocolVersion else { return }

        lastEvent = "Paquete recibido por mesh"
        onEnvelopeReceived?(envelope.relayed())
    }

    private func sendEnvelope(_ envelope: BejucoEnvelope, to peerID: UUID) {
        guard envelope.canRelay, let data = try? ProtocolCodec.encode(envelope) else { return }
        let encoded = data.base64EncodedString()
        let bytes = Array(encoded.utf8)
        let chunkSize = 24
        let totalChunks = max(1, Int(ceil(Double(max(1, bytes.count)) / Double(chunkSize))))
        let transferID = UUID().uuidString

        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, bytes.count)
            let chunk = String(decoding: bytes[start..<end], as: UTF8.self)
            let frame = MeshTransferFrame(
                kind: .packetChunk,
                senderId: nodeId,
                protocolVersion: BejucoEnvelope.protocolVersion,
                transferId: transferID,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                chunk: chunk
            )
            sendTransfer(frame, to: peerID)
        }
    }

    private func sendControl(_ frame: MeshControlFrame, to peerID: UUID) {
        guard let data = try? ProtocolCodec.encode(frame) else { return }
        if peripherals[peerID] != nil, controlCharacteristics[peerID] != nil {
            enqueueWrite(data, kind: .control, to: peerID)
        } else if let central = subscribedCentrals[peerID], let characteristic = controlCharacteristic {
            notify(data, characteristic: characteristic, central: central, peerID: peerID)
        }
    }

    private func sendTransfer(_ frame: MeshTransferFrame, to peerID: UUID) {
        guard let data = try? ProtocolCodec.encode(frame) else { return }
        if peripherals[peerID] != nil, transferCharacteristics[peerID] != nil {
            enqueueWrite(data, kind: .transfer, to: peerID)
        } else if let central = subscribedCentrals[peerID], let characteristic = transferCharacteristic {
            notify(data, characteristic: characteristic, central: central, peerID: peerID)
        }
    }

    /// Sends the emergency envelopes that Android can parse through the
    /// BitChat-compatible outer packet. Android's current Bejuco repository
    /// supports DISTRESS and SAFE; the other iOS-only message types continue
    /// using the native iOS transport until Android exposes them.
    private func sendStoredBitChatMessages(to peerID: UUID) {
        guard bitChatPacketCharacteristics[peerID] != nil || subscribedBitChatCentrals[peerID] != nil else { return }
        for envelope in (messageProvider?() ?? []) where envelope.canRelay {
            guard envelope.type == .distress || envelope.type == .safe else { continue }
            sendBitChatEnvelope(envelope, to: peerID)
        }
    }

    private func sendBitChatEnvelope(_ envelope: BejucoEnvelope, to peerID: UUID) {
        guard envelope.canRelay,
              envelope.type == .distress || envelope.type == .safe,
              let payload = try? AndroidEnvelopeCodec.encode(envelope),
              let senderID = BitChatPacketCodec.data(fromHex: nodeId) else { return }

        let packet = BitChatPacket(
            type: BitChatPacketCodec.bejucoEnvelopeType,
            ttl: 7,
            timestamp: UInt64(max(0, Date().timeIntervalSince1970 * 1_000)),
            senderID: senderID,
            recipientID: BitChatPacketCodec.broadcastRecipient,
            payload: payload
        )
        guard let frames = BitChatPacketCodec.prepareForBLE(packet) else {
            lastEvent = "No se pudo preparar el paquete para Android"
            return
        }
        for frame in frames {
            sendBitChatFrame(frame, to: peerID)
        }
        lastEvent = "Paquete Bejuco enviado por BitChat"
    }

    private func sendBitChatFrame(_ data: Data, to peerID: UUID) {
        if peripherals[peerID] != nil, bitChatPacketCharacteristics[peerID] != nil {
            enqueueWrite(data, kind: .bitChatPacket, to: peerID)
        } else if let central = subscribedBitChatCentrals[peerID], let characteristic = bitChatPacketCharacteristic {
            notify(data, characteristic: characteristic, central: central, peerID: peerID)
        }
    }

    private func handleBitChatData(_ data: Data, from peerID: UUID) {
        guard let packet = BitChatPacketCodec.decode(data) else {
            lastEvent = "Se recibió un paquete BitChat inválido"
            return
        }

        if packet.type == BitChatPacketCodec.fragmentType {
            handleBitChatFragment(packet, from: peerID)
        } else {
            handleBitChatPacket(packet)
        }
    }

    private func handleBitChatPacket(_ packet: BitChatPacket) {
        guard packet.type == BitChatPacketCodec.bejucoEnvelopeType,
              let envelope = try? AndroidEnvelopeCodec.decode(packet.payload),
              envelope.version <= BejucoEnvelope.protocolVersion else { return }

        lastEvent = "Paquete Bejuco recibido por BitChat"
        onEnvelopeReceived?(envelope.relayed())
    }

    private func handleBitChatFragment(_ packet: BitChatPacket, from peerID: UUID) {
        guard let fragment = BitChatFragment(payload: packet.payload),
              fragment.total <= BitChatPacketCodec.maxFragments,
              !fragment.data.isEmpty else { return }

        var peerFragments = bitChatFragmentBuffers[peerID] ?? [:]
        var assembly = peerFragments[fragment.fragmentID.hexString] ?? BitChatFragmentAssembly(
            total: fragment.total,
            originalType: fragment.originalType,
            chunks: [:]
        )
        guard assembly.total == fragment.total, assembly.originalType == fragment.originalType else {
            peerFragments[fragment.fragmentID.hexString] = nil
            bitChatFragmentBuffers[peerID] = peerFragments
            return
        }

        assembly.chunks[fragment.index] = fragment.data
        let bufferedBytes = assembly.chunks.values.reduce(0) { $0 + $1.count }
        guard bufferedBytes <= 1_048_576 else {
            peerFragments[fragment.fragmentID.hexString] = nil
            bitChatFragmentBuffers[peerID] = peerFragments
            return
        }

        if assembly.chunks.count == assembly.total {
            let assembled = (0..<assembly.total).reduce(into: Data()) { data, index in
                data.append(assembly.chunks[index] ?? Data())
            }
            peerFragments[fragment.fragmentID.hexString] = nil
            bitChatFragmentBuffers[peerID] = peerFragments
            guard let original = BitChatPacketCodec.decode(assembled),
                  original.type == assembly.originalType else { return }
            handleBitChatPacket(original)
        } else {
            peerFragments[fragment.fragmentID.hexString] = assembly
            bitChatFragmentBuffers[peerID] = peerFragments
        }
    }

    private func enqueueWrite(_ data: Data, kind: MeshWriteKind, to peerID: UUID) {
        pendingWrites[peerID, default: []].append(PendingWrite(data: data, kind: kind))
        flushWrites(to: peerID)
    }

    private func flushWrites(to peerID: UUID) {
        guard !activeWrites.contains(peerID),
              let peripheral = peripherals[peerID],
              var queue = pendingWrites[peerID],
              !queue.isEmpty else { return }

        let pending = queue.removeFirst()
        pendingWrites[peerID] = queue
        let characteristic: CBCharacteristic?
        switch pending.kind {
        case .control:
            characteristic = controlCharacteristics[peerID]
        case .transfer:
            characteristic = transferCharacteristics[peerID]
        case .bitChatPacket:
            characteristic = bitChatPacketCharacteristics[peerID]
        }
        guard let characteristic else { return }

        activeWrites.insert(peerID)
        // With-response writes provide a simple flow-control boundary for
        // packet chunks and avoid overflowing the iOS BLE write queue.
        peripheral.writeValue(pending.data, for: characteristic, type: .withResponse)
    }

    private func notify(_ data: Data, characteristic: CBMutableCharacteristic, central: CBCentral, peerID: UUID) {
        let delivered = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: [central])
        if !delivered {
            pendingNotifications[peerID, default: []].append(
                PendingNotification(data: data, characteristic: characteristic, central: central)
            )
        }
    }

    private func flushNotifications() {
        for peerID in Array(pendingNotifications.keys) {
            guard let central = subscribedCentrals[peerID], var queue = pendingNotifications[peerID] else { continue }
            while !queue.isEmpty {
                let pending = queue.removeFirst()
                let delivered = peripheralManager.updateValue(
                    pending.data,
                    for: pending.characteristic,
                    onSubscribedCentrals: [central]
                )
                if !delivered {
                    queue.insert(pending, at: 0)
                    break
                }
            }
            pendingNotifications[peerID] = queue
        }
    }
}

private struct InventoryAssembly {
    var pageCount: Int
    var pages: [Int: [String]]
}

private struct TransferAssembly {
    let totalChunks: Int
    var chunks: [Int: String]
}

private struct BitChatFragmentAssembly {
    let total: Int
    let originalType: UInt8
    var chunks: [Int: Data]
}

private enum MeshWriteKind {
    case control
    case transfer
    case bitChatPacket
}

private struct PendingWrite {
    let data: Data
    let kind: MeshWriteKind
}

private struct PendingNotification {
    let data: Data
    let characteristic: CBMutableCharacteristic
    let central: CBCentral
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let next = Swift.min(index + size, endIndex)
            result.append(Array(self[index..<next]))
            index = next
        }
        return result
    }
}

extension MeshService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateRuntimeState()
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            resetBluetoothPeerState()
            lastEvent = "Activa Bluetooth para conectar nodos"
        case .unauthorized:
            lastEvent = "Concede permiso de Bluetooth en Ajustes"
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        lastEvent = "Estado central BLE restaurado"
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral
        discoveredPeerCount = peripherals.count
        peripheral.delegate = self
        if !connectedPeripheralIDs.contains(peripheral.identifier) {
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier
        connectedPeripheralIDs.insert(id)
        updateConnectedPeerCount()
        lastEvent = "Conectado a un nodo cercano"
        peripheral.delegate = self
        peripheral.discoverServices([BejucoBLE.service, BejucoBLE.bitChatService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastEvent = "No se pudo conectar a un nodo"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        connectedPeripheralIDs.remove(id)
        controlCharacteristics[id] = nil
        transferCharacteristics[id] = nil
        bitChatPacketCharacteristics[id] = nil
        pendingWrites[id] = nil
        activeWrites.remove(id)
        pendingNotifications[id] = nil
        bitChatFragmentBuffers[id] = nil
        updateConnectedPeerCount()
        if central.state == .poweredOn { startScanning() }
    }
}

extension MeshService: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        for service in peripheral.services ?? [] {
            if service.uuid == BejucoBLE.service {
                peripheral.discoverCharacteristics([BejucoBLE.control, BejucoBLE.transfer], for: service)
            } else if service.uuid == BejucoBLE.bitChatService {
                peripheral.discoverCharacteristics([BejucoBLE.bitChatPacket], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        let id = peripheral.identifier
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == BejucoBLE.control {
                controlCharacteristics[id] = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == BejucoBLE.transfer {
                transferCharacteristics[id] = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == BejucoBLE.bitChatPacket {
                bitChatPacketCharacteristics[id] = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if controlCharacteristics[id] != nil && transferCharacteristics[id] != nil {
            sendHello(to: id)
        }
        if bitChatPacketCharacteristics[id] != nil {
            sendStoredBitChatMessages(to: id)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        let id = peripheral.identifier
        if characteristic.uuid == BejucoBLE.control {
            handleControl(data, from: id)
        } else if characteristic.uuid == BejucoBLE.transfer {
            handleTransfer(data, from: id)
        } else if characteristic.uuid == BejucoBLE.bitChatPacket {
            handleBitChatData(data, from: id)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let id = peripheral.identifier
        activeWrites.remove(id)
        if let error { lastEvent = "Error enviando por BLE: \(error.localizedDescription)" }
        flushWrites(to: id)
    }
}

extension MeshService: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        updateRuntimeState()
        if peripheral.state == .poweredOn {
            configurePeripheral()
        } else if peripheral.state == .poweredOff {
            resetBluetoothPeerState()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        lastEvent = "Estado periférico BLE restaurado"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { lastEvent = "Error al publicar BLE: \(error.localizedDescription)" }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if characteristic.uuid == BejucoBLE.bitChatPacket {
            subscribedBitChatCentrals[central.identifier] = central
            sendStoredBitChatMessages(to: central.identifier)
        } else {
            subscribedCentrals[central.identifier] = central
            sendHello(to: central.identifier)
        }
        updateConnectedPeerCount()
        lastEvent = "Un nodo se conectó al mesh"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == BejucoBLE.bitChatPacket {
            subscribedBitChatCentrals[central.identifier] = nil
        } else {
            subscribedCentrals[central.identifier] = nil
        }
        pendingNotifications[central.identifier] = nil
        updateConnectedPeerCount()
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushNotifications()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        request.value = Data()
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                if request.characteristic.uuid == BejucoBLE.control {
                    handleControl(data, from: request.central.identifier)
                } else if request.characteristic.uuid == BejucoBLE.transfer {
                    handleTransfer(data, from: request.central.identifier)
                } else if request.characteristic.uuid == BejucoBLE.bitChatPacket {
                    handleBitChatData(data, from: request.central.identifier)
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
