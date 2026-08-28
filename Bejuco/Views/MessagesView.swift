import SwiftUI

struct MessagesView: View {
    @ObservedObject var store: MessageStore
    let identity: IdentityService

    var body: some View {
        Group {
            if store.records.isEmpty {
                ContentUnavailableView(
                    "No hay paquetes",
                    systemImage: "shippingbox",
                    description: Text("Los paquetes creados o recibidos aparecerán aquí y quedarán disponibles offline.")
                )
            } else {
                List(store.records) { record in
                    NavigationLink {
                        MessageDetailView(record: record, identity: identity)
                    } label: {
                        MessageRow(record: record)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Paquetes")
    }
}

private struct MessageRow: View {
    let record: StoredMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.envelope.type.title)
                    .font(.headline)
                Text(record.envelope.location.map { String(format: "%.4f, %.4f", $0.lat, $0.lon) } ?? "Sin ubicación")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.envelope.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("hop \(record.envelope.hopCount)/\(record.envelope.hopLimit)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Text(uploadTitle)
                    .font(.caption2)
                    .foregroundStyle(uploadColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch record.envelope.type {
        case .distress: return "exclamationmark.triangle.fill"
        case .safe: return "checkmark.shield.fill"
        case .supplyRequest: return "shippingbox.fill"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    private var color: Color {
        record.envelope.type == .distress ? .bejucoAlert : .bejucoGreen
    }

    private var uploadTitle: String {
        switch record.uploadState {
        case .pending: return "pendiente"
        case .uploading: return "entregando"
        case .uploaded: return "entregado"
        case .failed: return "reintentar"
        }
    }

    private var uploadColor: Color {
        record.uploadState == .uploaded ? .bejucoLeaf : .secondary
    }
}

private struct MessageDetailView: View {
    let record: StoredMessage
    let identity: IdentityService

    var body: some View {
        List {
            Section("Resumen") {
                detail("Tipo", record.envelope.type.rawValue)
                detail("ID", record.envelope.messageId)
                detail("Origen", record.envelope.originId)
                detail("Saltos", "\(record.envelope.hopCount) / \(record.envelope.hopLimit)")
                detail("Entrega", record.uploadState.rawValue)
                detail("Firma", record.envelope.signature == nil ? "Ausente" : (identity.verify(record.envelope) ? "Válida" : "Inválida"))
            }

            if let location = record.envelope.location {
                Section("Ubicación") {
                    detail("Latitud", String(format: "%.6f", location.lat))
                    detail("Longitud", String(format: "%.6f", location.lon))
                    if let accuracy = location.accuracy { detail("Precisión", "±\(Int(accuracy)) m") }
                }
            }

            Section("Payload") {
                ForEach(record.envelope.payload.keys.sorted(), id: \.self) { key in
                    detail(key, record.envelope.payload[key] ?? "")
                }
            }
        }
        .navigationTitle(record.envelope.type.title)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.footnote).textSelection(.enabled)
        }
    }
}

