import SwiftUI

@main
struct BejucoApp: App {
    @StateObject private var appModel: AppModel

    init() {
        _appModel = StateObject(wrappedValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .tint(.bejucoGreen)
        }
    }
}

