import SwiftUI
import TapaCore

/// Every website left at basecamp in one table, filtered by list.
struct LeaveBehindView: View {
    @Environment(DaemonStore.self) private var daemon

    @State private var filter = LeaveBehindFilter.all
    @State private var pendingRemoval: PendingRemoval?
    @State private var isConfirmingRemoval = false
    @State private var isNamingList = false
    @State private var newListName = ""
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leave Behind")
                        .font(.largeTitle.bold())
                    Text("What stays at basecamp while you climb.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("New List") { isNamingList = true }
            }

            HStack {
                FilterPicker(filter: $filter, lists: config.leaveBehindLists, total: allEntryCount)
                Spacer()
                AddSiteField(lists: config.leaveBehindLists, preferredListID: filter.listID, add: add)
            }

            SitesTable(entries: SiteEntry.entries(in: config, filter: filter), canRemove: !isSummitRunning) { entry in
                requestRemoval(of: entry)
            }

            Text("""
                During Summit Mode you can add websites to a list, but not remove them. Apps like Discord \
                or games arrive in v1.1.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: config.leaveBehindLists.map(\.id)) { _, ids in
            if let id = filter.listID, !ids.contains(id) {
                filter = .all
            }
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.domain.value ?? "")?",
            isPresented: $isConfirmingRemoval,
            presenting: pendingRemoval
        ) { removal in
            Button(removalTitle(for: removal), role: .destructive) {
                remove(removal.domain, fromLists: removal.lists)
            }
        } message: { removal in
            Text(removalMessage(for: removal))
        }
        .alert("New List", isPresented: $isNamingList) {
            TextField("Name", text: $newListName)
            Button("Create", action: createList)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't Save Leave Behind", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var config: DaemonConfig {
        daemon.config
    }

    private var allEntryCount: Int {
        Set(config.leaveBehindLists.flatMap(\.domains)).count
    }

    private var isSummitRunning: Bool {
        daemon.snapshot?.mode == .summit
    }

    private func removalTitle(for removal: PendingRemoval) -> String {
        if let only = removal.lists.first, removal.lists.count == 1 {
            String(localized: "Remove from \(only.name)")
        } else {
            String(localized: "Remove from \(removal.lists.count) Lists")
        }
    }

    private func removalMessage(for removal: PendingRemoval) -> String {
        let names = removal.lists.map(\.name).formatted(.list(type: .and))
        return removal.lists.count == 1
            ? String(localized: "It's only in \(names).")
            : String(localized: "It's in \(names). Removing it here takes it out of all of them.")
    }

    /// From one list, the website leaves that list. From All, it leaves every list, after the
    /// user sees which ones.
    private func requestRemoval(of entry: SiteEntry) {
        if let id = filter.listID, let list = entry.lists.first(where: { $0.id == id }) {
            remove(entry.domain, fromLists: [list])
        } else {
            pendingRemoval = PendingRemoval(domain: entry.domain, lists: entry.lists)
            isConfirmingRemoval = true
        }
    }

    private func add(_ domain: DomainName, to listID: LeaveBehindList.ID) {
        var updated = config
        updated.add(domain, toList: listID)
        apply(updated)
    }

    private func remove(_ domain: DomainName, fromLists lists: [LeaveBehindList]) {
        var updated = config
        updated.remove(domain, fromLists: Set(lists.map(\.id)))
        apply(updated)
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        guard !name.isEmpty else { return }
        let list = LeaveBehindList(name: name, domains: [])
        var updated = config
        updated.leaveBehindLists.append(list)
        apply(updated)
        filter = .list(list.id)
    }

    private func apply(_ updated: DaemonConfig) {
        Task {
            do {
                try await daemon.updateConfig(updated)
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
