import SwiftUI

struct ContentView: View {
    private static let sidebarAnimation = Animation.smooth(duration: 0.3)

    @State private var selection: SidebarItem? = .basecamp
    @SceneStorage("isSidebarVisible") private var isSidebarVisible = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailView(item: selection ?? .basecamp)
                .safeAreaPadding(.leading, reservesSidebarSpace ? SidebarPanel.occupiedWidth : 0)

            // Kept in place and slid aside, because inserting and removing glass doesn't animate.
            SidebarPanel(selection: $selection)
                .offset(x: isSidebarVisible ? 0 : -SidebarPanel.occupiedWidth)
                .disabled(!isSidebarVisible)
                .accessibilityHidden(!isSidebarVisible)
        }
        .animation(Self.sidebarAnimation, value: isSidebarVisible)
        .toolbar {
            SidebarToggle(isSidebarVisible: isSidebarVisible) { isSidebarVisible.toggle() }
        }
        .frame(minWidth: WindowSize.minimum.width, minHeight: WindowSize.minimum.height)
    }

    /// Photo screens run under the sidebar so their content stays put; other screens make room.
    private var reservesSidebarSpace: Bool {
        isSidebarVisible && !(selection ?? .basecamp).isImmersive
    }
}
