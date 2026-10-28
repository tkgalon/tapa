import AppKit
import SwiftUI

/// A material that blurs what is behind the window, not just behind the view. SwiftUI's materials
/// blur within the window, so a sheet backed by one shows none of the window under it.
struct BehindWindowMaterial: NSViewRepresentable {
    var material = NSVisualEffectView.Material.popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
