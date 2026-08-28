import SwiftUI

enum BejucoTab: Hashable {
    case home
    case emergency
    case alerts
    case messages
    case settings
}

struct ContentView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        TabView(selection: $app.selectedTab) {
            NavigationStack {
                DashboardView(
                    store: app.store,
                    mesh: app.mesh,
                    gateway: app.gateway,
                    location: app.location
                )
            }
            .tabItem { Label("Inicio", systemImage: "leaf.fill") }
            .tag(BejucoTab.home)

            NavigationStack {
                EmergencyView(settings: app.settings, location: app.location)
            }
            .tabItem { Label("Emergencia", systemImage: "exclamationmark.triangle.fill") }
            .tag(BejucoTab.emergency)

            NavigationStack {
                AlertsView(store: app.store, identity: app.identity)
            }
            .tabItem { Label("Alertas", systemImage: "bell.badge.fill") }
            .tag(BejucoTab.alerts)

            NavigationStack {
                MessagesView(store: app.store, identity: app.identity)
            }
            .tabItem { Label("Paquetes", systemImage: "shippingbox.fill") }
            .tag(BejucoTab.messages)

            NavigationStack {
                SettingsView(
                    settings: app.settings,
                    mesh: app.mesh,
                    gateway: app.gateway,
                    notifications: app.notifications
                )
            }
            .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
            .tag(BejucoTab.settings)
        }
    }
}
