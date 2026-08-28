import CoreLocation
import SwiftUI

struct EmergencyView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var location: LocationService

    @State private var name = ""
    @State private var phone = ""
    @State private var contactName = ""
    @State private var notes = ""
    @State private var priority: BejucoPriority = .critical
    @State private var supplyItem = ""
    @State private var supplyQuantity = ""
    @State private var showingSupplyForm = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reporta tu estado", systemImage: "exclamationmark.triangle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(Color.bejucoAlert)
                    Text("El paquete se firma, se guarda localmente y se replica cuando aparezca otro nodo Bejuco cercano.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ubicación") {
                HStack {
                    Image(systemName: location.currentLocation == nil ? "location.slash" : "location.fill")
                        .foregroundStyle(location.currentLocation == nil ? .orange : Color.bejucoLeaf)
                    if let current = location.currentLocation {
                        Text(String(format: "%.5f, %.5f", current.lat, current.lon))
                            .font(.footnote.monospaced())
                    } else {
                        Text("No disponible")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Actualizar") {
                        location.requestCurrentLocation()
                    }
                }
                if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
                    Text("Permite la ubicación en Ajustes para incluir latitud y longitud en el SOS.")
                        .font(.caption)
                        .foregroundStyle(Color.bejucoAlert)
                } else if location.currentLocation == nil {
                    Button("Activar ubicación") {
                        location.requestPermission()
                        location.requestCurrentLocation()
                    }
                }
            }

            Section("Datos de contacto") {
                TextField("Nombre", text: $name)
                    .textContentType(.name)
                TextField("Teléfono", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Nombre de contacto de emergencia", text: $contactName)
                TextField("Notas para los equipos de ayuda", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                Picker("Prioridad", selection: $priority) {
                    ForEach(BejucoPriority.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }

            Section {
                Button {
                    if app.publishDistress(name: name, phone: phone, contactName: contactName, notes: notes, priority: priority) {
                        notes = ""
                    }
                } label: {
                    Label("Guardar y transmitir SOS", systemImage: "megaphone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.bejucoAlert)

                Button {
                    _ = app.publishSafe(notes: notes)
                    notes = ""
                } label: {
                    Label("Reportar que estoy a salvo", systemImage: "checkmark.shield.fill")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                DisclosureGroup("Centro de acopio · solicitar insumos", isExpanded: $showingSupplyForm) {
                    TextField("Insumo necesario", text: $supplyItem)
                    TextField("Cantidad", text: $supplyQuantity)
                    TextField("Detalles", text: $notes, axis: .vertical)
                    Button("Guardar solicitud") {
                        if app.publishSupplyRequest(item: supplyItem, quantity: supplyQuantity, notes: notes) {
                            supplyItem = ""
                            supplyQuantity = ""
                            notes = ""
                            showingSupplyForm = false
                        }
                    }
                }
            }

            if let feedback = app.feedbackMessage {
                Section {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Emergencia")
        .onAppear {
            if name.isEmpty { name = settings.displayName }
            if phone.isEmpty { phone = settings.phone }
            if contactName.isEmpty { contactName = settings.emergencyContact }
            if location.authorizationStatus == .notDetermined {
                location.requestPermission()
            }
            location.requestCurrentLocation()
        }
    }
}

