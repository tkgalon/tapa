import SwiftUI

/// The toolbar button that shows and hides the sidebar, drawn plainly so it sits inside the panel.
struct SidebarToggle: ToolbarContent {
    let isSidebarVisible: Bool
    let toggle: () -> Void

    var body: some ToolbarContent {
        if #available(macOS 26, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
        }
    }

    private var item: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(
                isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                systemImage: "sidebar.left",
                action: toggle
            )
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
    }
}
