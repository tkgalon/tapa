import SwiftUI
import TapaCore

/// The site's icon, or its first letter until the icon can be fetched.
struct SiteIcon: View {
    let domain: DomainName
    /// Passed in rather than read from the environment: a Table row being torn down while the
    /// rows change can lose the environment and crash on the lookup.
    let favicons: FaviconStore

    var body: some View {
        Group {
            if let icon = favicons.icon(for: domain) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Text(verbatim: domain.value.prefix(1).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.glacierInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.glacierTint)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(.rect(cornerRadius: 5))
        .accessibilityHidden(true)
        .task(id: domain) {
            await favicons.load(domain)
        }
    }
}
