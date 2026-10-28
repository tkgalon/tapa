import SwiftUI

struct ContentView: View {
    private static let sidebarAnimation = Animation.smooth(duration: 0.3)

    @Environment(DaemonStore.self) private var daemon
    @Environment(AppRouter.self) private var router
    @SceneStorage("isSidebarVisible") private var isSidebarVisible = true

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .topLeading) {
            DetailView(item: selection ?? .basecamp)
                .safeAreaPadding(.leading, reservesSidebarSpace ? SidebarPanel.occupiedWidth : 0)

            // Kept in place and slid aside, because inserting and removing glass doesn't animate.
            SidebarPanel(selection: $router.selection, isFullHeight: !(selection ?? .basecamp).isImmersive)
                .offset(x: isSidebarVisible ? 0 : -SidebarPanel.occupiedWidth)
                .disabled(!isSidebarVisible)
                .accessibilityHidden(!isSidebarVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(Self.sidebarAnimation, value: isSidebarVisible)
        .toolbar {
            SidebarToggle(isSidebarVisible: isSidebarVisible) { isSidebarVisible.toggle() }
        }
        .transparentToolbar()
        .frame(minWidth: WindowSize.minimum.width, minHeight: WindowSize.minimum.height)
        // Sheets live here so the menu bar can bring them up too.
        .sheet(item: $router.pendingOath) { pending in
            OathSheet(request: pending.request)
        }
        .sheet(isPresented: $router.isShowingDescent) {
            DescentSheet(
                descentsRemaining: daemon.snapshot?.descentsRemaining ?? 0,
                summitEndsAt: daemon.snapshot?.endsAt
            )
        }
        .onOpenURL { url in
            router.open(url)
            NSApp.activate()
        }
        .alert("Couldn't Change the Ascent", isPresented: $router.isShowingFailure, presenting: router.failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var selection: SidebarItem? {
        router.selection
    }

    /// Photo screens run under the sidebar so their content stays put; other screens make room.
    private var reservesSidebarSpace: Bool {
        isSidebarVisible && !(selection ?? .basecamp).isImmersive
    }
}
