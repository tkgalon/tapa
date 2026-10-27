import SwiftUI

extension View {
    /// Lets a full-bleed photo run under the window toolbar, without the window title on top.
    @ViewBuilder
    func photoToolbar() -> some View {
        if #available(macOS 15, *) {
            toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            toolbarBackground(.hidden, for: .windowToolbar)
        }
    }
}
