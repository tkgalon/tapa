import SwiftUI

extension View {
    /// Lets content run under the window toolbar, without the window title on top.
    @ViewBuilder
    func transparentToolbar() -> some View {
        if #available(macOS 15, *) {
            toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            toolbarBackground(.hidden, for: .windowToolbar)
        }
    }
}
