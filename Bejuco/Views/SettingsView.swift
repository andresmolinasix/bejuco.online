import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var mesh: MeshService
    @ObservedObject var gateway: GatewayService
    @ObservedObject var notifications: NotificationService

    var body: some View {
        Form {
            Section("Perfil de emergencia") {
                TextField("Nombre", text: $settings.displayName)
                TextField("Teléfono", text: $settings.phone)
                    .keyboardType(.phonePad)
                TextField("Contacto de emergencia", text: $settings.emergencyContact)
                Picker("Rol del nodo", selection: $settings.role) {
                    ForEach(NodeRole.allCases) { role in
                        Text(role.title).tag(role)
                    }
                }
                Toggle("Participar como relevo", isOn: $settings.relayingEnabled)
            }

            Section("Gateway de Internet") {
                TextField("https://…/v1/messages/batch", text: $settings.gatewayURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    StatusDot(color: gateway.isConnected ? .bejucoLeaf : .orange)
                    Text(gateway.statusText)
                        .font(.footnote)
                    Spacer()
                    if gateway.isUploading { ProgressView() }
                }
                Button("Entregar paquetes pendientes") {
                    gateway.syncPending()
                }
                if let message = gateway.lastUploadMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Alertas de emergencia") {
                HStack {
                    StatusDot(color: notifications.isAuthorized ? .bejucoLeaf : .orange)
                    Text(notifications.statusTitle)
                        .font(.footnote)
                    Spacer()
                }

                if notifications.isAuthorized {
                    Text("Recibirás un banner y sonido cuando llegue un DISTRESS validado por Bluetooth.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if notifications.authorizationStatus == .denied {
                    Text("Las notificaciones están bloqueadas. Actívalas en los ajustes de iOS para recibir alertas aunque la app esté en segundo plano.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Abrir Ajustes de iOS") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                } else {
                    Button("Activar notificaciones") {
                        notifications.requestAuthorization()
                    }
                }

                if let error = notifications.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.bejucoAlert)
                }
            }

            Section("Identidad y mesh") {
                LabeledContent("Estado", value: mesh.state.title)
                LabeledContent("Nodos conectados", value: "\(mesh.connectedPeerCount)")
                LabeledContent("Nodo local", value: mesh.nodeId)
                    .textSelection(.enabled)
                Text("La identidad de este dispositivo se conserva en Keychain y se usa para firmar los paquetes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacidad y límites") {
                Text("La ubicación, nombre y teléfono solo se incluyen cuando tú creas un paquete de emergencia. El mesh no es un chat y los mensajes expiran según el protocolo.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Ajustes")
    }
}
