import SwiftUI

@main
struct TapaApp: App {
    @State private var daemon = DaemonStore()
    @State private var favicons = FaviconStore()

    var body: some Scene {
        Window("Tapa", id: "main") {
            ContentView()
                .environment(daemon)
                .environment(favicons)
                .task { await daemon.run() }
        }
        .defaultSize(WindowSize.minimum)
        .windowResizability(.contentMinSize)
    }
}
