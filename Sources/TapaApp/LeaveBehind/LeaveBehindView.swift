import SwiftUI
import TapaCore

/// Named lists of websites that stay at basecamp during an Ascent.
struct LeaveBehindView: View {
    @Environment(DaemonStore.self) private var daemon

    @State private var selectedListID: LeaveBehindList.ID?
    @State private var isNamingList = false
    @State private var newListName = ""
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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

            HStack(alignment: .top, spacing: 16) {
                List(daemon.config.leaveBehindLists, selection: $selectedListID) { list in
                    LabeledContent(list.name) {
                        Text(list.domains.count, format: .number)
                    }
                }
                .frame(width: 200)

                if let list = daemon.config.leaveBehindLists.first(where: { $0.id == selectedListID }) {
                    LeaveBehindListDetail(list: list, save: save)
                } else {
                    ContentUnavailableView("No List Selected", systemImage: "nosign")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: daemon.config.leaveBehindLists.map(\.id), initial: true) { _, ids in
            if selectedListID.map(ids.contains) != true {
                selectedListID = ids.first
            }
        }
        .alert("New List", isPresented: $isNamingList) {
            TextField("Name", text: $newListName)
            Button("Create", action: createList)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't Save the List", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        guard !name.isEmpty else { return }
        let list = LeaveBehindList(name: name, domains: [])
        var config = daemon.config
        config.leaveBehindLists.append(list)
        apply(config)
        selectedListID = list.id
    }

    private func save(_ list: LeaveBehindList) {
        var config = daemon.config
        guard let index = config.leaveBehindLists.firstIndex(where: { $0.id == list.id }) else { return }
        config.leaveBehindLists[index] = list
        apply(config)
    }

    private func apply(_ config: DaemonConfig) {
        Task {
            do {
                try await daemon.updateConfig(config)
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
