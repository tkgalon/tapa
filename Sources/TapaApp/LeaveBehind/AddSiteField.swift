import SwiftUI
import TapaCore

/// A website and the list it goes into. The list follows the filter, so adding while one list is
/// shown adds to that list.
struct AddSiteField: View {
    let lists: [LeaveBehindList]
    let preferredListID: LeaveBehindList.ID?
    let add: (DomainName, LeaveBehindList.ID) -> Void

    @State private var text = ""
    @State private var targetID: LeaveBehindList.ID?
    @State private var isShowingInvalidDomain = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a website, like reddit.com", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit(submit)
            Picker("To", selection: $targetID) {
                ForEach(lists) { list in
                    Text(list.name).tag(Optional(list.id))
                }
            }
            .fixedSize()
        }
        .disabled(lists.isEmpty)
        .onChange(of: preferredListID ?? lists.first?.id, initial: true) { _, id in
            targetID = id
        }
        .alert("That Isn't a Website Address", isPresented: $isShowingInvalidDomain) {
            Button("OK") {}
        } message: {
            Text("Type a domain such as reddit.com, without https:// or a path.")
        }
    }

    private func submit() {
        guard let targetID else { return }
        guard let domain = DomainName(text) else {
            isShowingInvalidDomain = true
            return
        }
        text = ""
        add(domain, targetID)
    }
}
