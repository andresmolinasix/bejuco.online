import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(
                    store: app.store,
                    mesh: app.mesh,
                    gateway: app.gateway,
                    location: app.location
                )
            }
            .tabItem { Label("Inicio", systemImage: "leaf.fill") }

            NavigationStack {
                EmergencyView(settings: app.settings, location: app.location)
            }
            .tabItem { Label("Emergencia", systemImage: "exclamationmark.triangle.fill") }

            NavigationStack {
                MessagesView(store: app.store, identity: app.identity)
            }
            .tabItem { Label("Paquetes", systemImage: "shippingbox.fill") }

            NavigationStack {
                SettingsView(settings: app.settings, mesh: app.mesh, gateway: app.gateway)
            }
            .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
    }
}

