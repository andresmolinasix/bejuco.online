import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MessageStore
    @ObservedObject var mesh: MeshService
    @ObservedObject var gateway: GatewayService
    @ObservedObject var location: LocationService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                connectivityCards
                emergencyActions
                earthquakeCard
                packageSummary
            }
            .padding()
        }
        .background(Color.bejucoSand.opacity(0.55))
        .navigationTitle("Bejuco")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.refreshEarthquakes()
                } label: {
                    Image(systemName: app.isRefreshingEarthquakes ? "arrow.clockwise" : "arrow.clockwise.circle")
                }
                .disabled(app.isRefreshingEarthquakes)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comunicación cuando más importa")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.bejucoGreen)
            Text("Tus paquetes se guardan en el teléfono y buscan rutas cercanas por Bluetooth Low Energy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var connectivityCards: some View {
        HStack(spacing: 12) {
            statusCard(
                title: "Mesh",
                value: mesh.state.title,
                systemImage: "dot.radiowaves.left.and.right",
                color: mesh.state == .active ? .bejucoLeaf : .bejucoAlert
            )
            statusCard(
                title: "Internet",
                value: gateway.isConnected ? "Disponible" : "Offline",
                systemImage: gateway.isConnected ? "globe" : "wifi.slash",
                color: gateway.isConnected ? .bejucoLeaf : .orange
            )
        }
    }

    private func statusCard(title: String, value: String, systemImage: String, color: Color) -> some View {
        BejucoCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(2)
            }
        }
    }

    private var emergencyActions: some View {
        BejucoCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Acciones rápidas", systemImage: "bolt.fill")
                    .font(.headline)
                HStack(spacing: 10) {
                    NavigationLink {
                        EmergencyView(settings: app.settings, location: app.location)
                    } label: {
                        Label("Necesito ayuda", systemImage: "exclamationmark.triangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.bejucoAlert)

                    Button {
                        _ = app.publishSafe(notes: "Estado reportado desde la pantalla principal.")
                    } label: {
                        Label("Estoy a salvo", systemImage: "checkmark.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let feedback = app.feedbackMessage {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var earthquakeCard: some View {
        BejucoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Alerta sísmica USGS", systemImage: "waveform.path.ecg")
                        .font(.headline)
                    Spacer()
                    if app.isRefreshingEarthquakes { ProgressView() }
                }
                if let event = app.latestEarthquake {
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.magnitude.map { String(format: "M %.1f", $0) } ?? "M —")
                            .font(.title2.bold())
                            .foregroundStyle(event.isSignificant ? Color.bejucoAlert : Color.bejucoGreen)
                        Text(event.place ?? event.title)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    if let date = event.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("La alerta no envía datos personales automáticamente. Tú decides si reportas ayuda o seguridad.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Aún no hay eventos cargados. Actualiza cuando tengas conexión.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var packageSummary: some View {
        BejucoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Almacén local", systemImage: "externaldrive.fill")
                    .font(.headline)
                HStack {
                    metric(value: "\(store.records.count)", label: "paquetes")
                    Divider().frame(height: 38)
                    metric(value: "\(mesh.connectedPeerCount)", label: "nodos conectados")
                    Divider().frame(height: 38)
                    metric(value: "\(store.pendingUpload.count)", label: "por entregar")
                }
                HStack(spacing: 6) {
                    StatusDot(color: location.currentLocation == nil ? .orange : .bejucoLeaf)
                    Text(location.currentLocation == nil ? "Ubicación pendiente" : "Ubicación lista para reportar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

