import SwiftUI

@main
struct TapaApp: App {
    @State private var daemon = DaemonStore()
    @State private var favicons = FaviconStore()
    @State private var router = AppRouter()

    var body: some Scene {
        Window("Tapa", id: "main") {
            ContentView()
                .environment(daemon)
                .environment(favicons)
                .environment(router)
        }
        .defaultSize(WindowSize.minimum)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarMenu()
                .environment(daemon)
                .environment(router)
        } label: {
            MenuBarLabel()
                .environment(daemon)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(daemon)
        }
    }
}
