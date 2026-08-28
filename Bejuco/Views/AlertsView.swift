import SwiftUI

struct AlertsView: View {
    @ObservedObject var store: MessageStore
    let identity: IdentityService

    private var alerts: [StoredMessage] {
        store.records.filter { $0.envelope.type == .distress }
    }

    var body: some View {
        Group {
            if alerts.isEmpty {
                ContentUnavailableView(
                    "No hay alertas",
                    systemImage: "bell.slash",
                    description: Text("Las solicitudes de ayuda recibidas desde Android o desde otro nodo aparecerán aquí.")
                )
            } else {
                List {
                    Section {
                        ForEach(alerts) { record in
                            NavigationLink {
                                MessageDetailView(record: record, identity: identity)
                            } label: {
                                AlertRow(record: record)
                            }
                        }
                    } header: {
                        Text("Solicitudes de ayuda")
                    } footer: {
                        Text("Cada alerta fue verificada y guardada localmente antes de mostrarse.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Alertas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(alerts.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(alerts.count) alertas")
            }
        }
    }
}

private struct AlertRow: View {
    let record: StoredMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.bejucoAlert)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.envelope.payload["name"]?.nilIfEmpty ?? "Solicitud de ayuda")
                    .font(.headline)
                Text(isDemo ? "DEMO LOCAL" : record.envelope.priority.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDemo ? .orange : Color.bejucoAlert)
                Text(record.envelope.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("hop \(record.envelope.hopCount)/\(record.envelope.hopLimit)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                if let location = record.envelope.location {
                    Text(String(format: "%.3f, %.3f", location.lat, location.lon))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
    }

    private var isDemo: Bool {
        record.envelope.payload["demo"] == "true"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
