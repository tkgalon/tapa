import SwiftUI
import TapaCore

/// The Leave Behind lists for the Ascent. Several can be chosen, so the popover stays open.
struct ListsButton: View {
    @Binding var selection: Set<LeaveBehindList.ID>
    let lists: [LeaveBehindList]

    @Environment(AppRouter.self) private var router

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(summary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
        }
        .accessibilityLabel(Text("Leave Behind: \(summary)"))
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(spacing: 2) {
                if lists.isEmpty {
                    Button("Create a List in Leave Behind…") {
                        isPresented = false
                        router.selection = .leaveBehind
                    }
                    .buttonStyle(.borderless)
                    .padding(8)
                }
                ForEach(lists) { list in
                    ChoiceRow(isSelected: selection.contains(list.id)) {
                        selection[contains: list.id].toggle()
                    } title: {
                        Text(list.name)
                    }
                }
            }
            .padding(6)
            .frame(minWidth: 160)
        }
    }

    private var summary: String {
        let names = lists.filter { selection.contains($0.id) }.map(\.name)
        if lists.isEmpty {
            return String(localized: "No Lists")
        }
        return names.isEmpty ? String(localized: "Choose Lists") : names.formatted(.list(type: .and))
    }
}
