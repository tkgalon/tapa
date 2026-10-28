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
    @State private var renaming: LeaveBehindList?
    @State private var renamedListName = ""
    @State private var deleting: LeaveBehindList?
    @State private var isConfirmingDelete = false
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

            if config.leaveBehindLists.isEmpty {
                noLists
            } else {
                HStack {
                    FilterPicker(filter: $filter, lists: config.leaveBehindLists, total: allEntryCount)
                    if let list = selectedList {
                        ListActionsMenu(
                            canDelete: !isLocked(list),
                            rename: { startRenaming(list) },
                            delete: { requestDeletion(of: list) }
                        )
                    }
                    Spacer()
                    AddSiteField(lists: config.leaveBehindLists, preferredListID: filter.listID, add: add)
                }

                SitesTable(
                    entries: SiteEntry.entries(in: config, filter: filter),
                    canRemove: !isSummitRunning
                ) { entry in
                    requestRemoval(of: entry)
                }
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
        .alert("Rename List", isPresented: renamingBinding, presenting: renaming) { list in
            TextField("Name", text: $renamedListName)
            Button("Rename") { rename(list) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \(deleting?.name ?? "")?",
            isPresented: $isConfirmingDelete,
            presenting: deleting
        ) { list in
            Button("Delete List", role: .destructive) { delete(list) }
        } message: { list in
            Text(deletionMessage(for: list))
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

    private var noLists: some View {
        ContentUnavailableView {
            Label("No Lists Yet", systemImage: "nosign")
        } description: {
            Text("A list holds the websites to leave behind. Begin Ascent and Rituals need one.")
        } actions: {
            Button("New List") { isNamingList = true }
                .buttonStyle(.borderedProminent)
                .tint(.glacier)
        }
        .frame(maxHeight: .infinity)
    }

    private var selectedList: LeaveBehindList? {
        filter.listID.flatMap { id in config.leaveBehindLists.first { $0.id == id } }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    /// Summit Mode holds the lists it enforces until it ends.
    private func isLocked(_ list: LeaveBehindList) -> Bool {
        isSummitRunning && daemon.activeLists.contains { $0.id == list.id }
    }

    private func startRenaming(_ list: LeaveBehindList) {
        renamedListName = list.name
        renaming = list
    }

    private func rename(_ list: LeaveBehindList) {
        let name = renamedListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = config.leaveBehindLists.firstIndex(where: { $0.id == list.id }) else {
            return
        }
        var updated = config
        updated.leaveBehindLists[index].name = name
        apply(updated)
    }

    /// A Ritual can't be left without a list, so the user picks another one for it first.
    private func requestDeletion(of list: LeaveBehindList) {
        let stranded = config.ritualsOnlyUsing(list.id).map(\.name)
        guard stranded.isEmpty else {
            failure = String(localized: """
                \(list.name) is the only list for \(stranded.formatted(.list(type: .and))). Pick another \
                list in Rituals first.
                """)
            isShowingFailure = true
            return
        }
        deleting = list
        isConfirmingDelete = true
    }

    private func deletionMessage(for list: LeaveBehindList) -> String {
        let leaving = config.websitesOnlyIn(list.id).count
        let kept = list.domains.count - leaving
        var parts = [String]()
        if leaving > 0 {
            parts.append(String(localized: "^[\(leaving) website](inflect: true) only in this list will be removed."))
        }
        if kept > 0 {
            parts.append(String(localized: "^[\(kept) website](inflect: true) also in other lists will stay there."))
        }
        let rituals = config.rituals(using: [list.id]).map(\.name)
        if !rituals.isEmpty {
            parts.append(String(localized: "It will be taken out of \(rituals.formatted(.list(type: .and)))."))
        }
        return parts.isEmpty ? String(localized: "This list is empty.") : parts.joined(separator: " ")
    }

    private func delete(_ list: LeaveBehindList) {
        var updated = config
        updated.deleteList(list.id)
        filter = .all
        apply(updated)
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
