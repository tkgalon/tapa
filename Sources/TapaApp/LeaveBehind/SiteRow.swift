import SwiftUI
import TapaCore

struct SiteRow: View {
    let domain: DomainName
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SiteIcon(domain: domain)
            VStack(alignment: .leading, spacing: 1) {
                Text(domain.value)
                Text("Includes \(DomainName.commonSubdomains.formatted(.list(type: .and, width: .narrow)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove \(domain.value)", systemImage: "minus.circle.fill", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(!canRemove)
        }
        .padding(.vertical, 4)
    }
}
