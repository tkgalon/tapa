import SwiftUI
import TapaCore

/// The websites in one list, with a field to add more.
struct LeaveBehindListDetail: View {
    let list: LeaveBehindList
    let save: (LeaveBehindList) -> Void

    @Environment(DaemonStore.self) private var daemon

    @State private var newDomain = ""
    @State private var isShowingInvalidDomain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.name)
                    .font(.title3.weight(.semibold))
                Spacer()
                if !ritualNames.isEmpty {
                    Text("Used by \(ritualNames.formatted(.list(type: .and)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Add a website, like reddit.com", text: $newDomain)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addDomain)

            List(list.domains, id: \.value) { domain in
                SiteRow(domain: domain, canRemove: !isSummitRunning) {
                    remove(domain)
                }
            }
            .listStyle(.inset)
            .clipShape(.rect(cornerRadius: 12))

            Text("""
                During Summit Mode you can add websites to this list, but not remove them. Apps like Discord \
                or games arrive in v1.1.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .alert("That Isn't a Website Address", isPresented: $isShowingInvalidDomain) {
            Button("OK") {}
        } message: {
            Text("Type a domain such as reddit.com, without https:// or a path.")
        }
    }

    private var ritualNames: [String] {
        daemon.config.rituals.filter { $0.leaveBehindIDs.contains(list.id) }.map(\.name)
    }

    private var isSummitRunning: Bool {
        daemon.snapshot?.mode == .summit
    }

    private func addDomain() {
        guard let domain = DomainName(newDomain) else {
            isShowingInvalidDomain = true
            return
        }
        newDomain = ""
        guard !list.domains.contains(domain) else { return }
        var updated = list
        updated.domains.append(domain)
        save(updated)
    }

    private func remove(_ domain: DomainName) {
        var updated = list
        updated.domains.removeAll { $0 == domain }
        save(updated)
    }
}
