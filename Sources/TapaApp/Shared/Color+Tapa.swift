import AppKit
import SwiftUI

extension Color {
    /// Glacier teal, for primary actions and selection.
    static let glacier = Color(light: 0x286B7C, dark: 0x7FC0CF)
    /// Background for fallback site icons and suggestions.
    static let glacierTint = Color(light: 0xDDEBEE, dark: 0x1D3A42)
    /// Text on `glacierTint`.
    static let glacierInk = Color(light: 0x24525E, dark: 0xA6D6E0)
    /// The committing button of The Summit Oath. White text reads on it in both appearances.
    static let summitNight = Color(light: 0x1D3448, dark: 0x2C4A63)
    /// Ritual colors, ordered so neighbours in the list look nothing alike. White text reads on each
    /// in both appearances.
    private static let ritualColors: [UInt32] = [0x286B7C, 0xC0502A, 0x8045A8, 0x3A8150, 0x2F66B8, 0x946A0E, 0xB03A62]

    /// The color of the Ritual at `index` in the list, repeating once the palette runs out.
    static func ritual(at index: Int) -> Color {
        let rgb = ritualColors[index % ritualColors.count]
        return Color(light: rgb, dark: rgb)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
