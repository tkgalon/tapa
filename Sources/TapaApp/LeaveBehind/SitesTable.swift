import SwiftUI
import TapaCore

/// Every website in view, its lists, what else it blocks and which Rituals use it.
struct SitesTable: View {
    let entries: [SiteEntry]
    let canRemove: Bool
    let remove: (SiteEntry) -> Void

    @State private var sortOrder = [KeyPathComparator(\SiteEntry.name)]

    var body: some View {
        Table(entries.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("Website", value: \.name) { entry in
                HStack(spacing: 10) {
                    SiteIcon(domain: entry.domain)
                    Text(entry.name)
                }
            }
            .width(min: 160, ideal: 200)

            TableColumn("List") { entry in
                TagChips(names: entry.lists.map(\.name))
            }
            .width(min: 90, ideal: 150)

            TableColumn("Also Blocks") { _ in
                Text(DomainName.commonSubdomains.formatted(.list(type: .and, width: .narrow)))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Used By") { entry in
                if entry.rituals.isEmpty {
                    Text("No Ritual")
                        .foregroundStyle(.tertiary)
                } else {
                    TagChips(names: entry.rituals.map(\.name), limit: 1)
                }
            }
            .width(min: 110, ideal: 160)

            TableColumn("") { entry in
                Button("Remove \(entry.name)", systemImage: "minus.circle.fill") {
                    remove(entry)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(!canRemove)
                .help(canRemove ? "Remove \(entry.name)" : "Websites can't be removed during Summit Mode.")
            }
            .width(28)
        }
        .alternatingRowBackgrounds(.disabled)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Websites",
                    systemImage: "nosign",
                    description: Text("Add one above, like reddit.com.")
                )
            }
        }
    }
}
