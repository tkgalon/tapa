import SwiftUI

/// Rename or delete the list in view.
struct ListActionsMenu: View {
    /// False for a list Summit Mode is enforcing.
    let canDelete: Bool
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        Menu {
            Button("Rename List…", action: rename)
            Divider()
            Button("Delete List…", role: .destructive, action: delete)
                .disabled(!canDelete)
        } label: {
            Label("List Actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Rename or delete this list")
    }
}
