import SwiftUI

extension PrimitiveButtonStyle where Self == GlassIfAvailableButtonStyle {
    /// The glass button on macOS 26 and later, bordered before that.
    static var glassIfAvailable: GlassIfAvailableButtonStyle { GlassIfAvailableButtonStyle() }
}

struct GlassIfAvailableButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            Button(configuration).buttonStyle(.glass)
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}
