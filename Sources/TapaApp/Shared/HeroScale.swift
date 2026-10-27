import CoreGraphics

/// How much the large text over a photo grows with the window, so a bigger window keeps the
/// proportions of the default one. Controls keep their standard size.
enum HeroScale {
    private static let maximum: CGFloat = 1.75

    static func factor(for size: CGSize) -> CGFloat {
        let base = WindowSize.minimum
        let ratio = min(size.width / base.width, size.height / base.height)
        return min(max(ratio, 1), maximum)
    }
}
