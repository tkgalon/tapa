import SwiftUI
import TapaCore

/// All websites or one list's. Segments while the lists fit, a pop-up button past that.
struct FilterPicker: View {
    private static let maximumSegments = 5

    @Binding var filter: LeaveBehindFilter
    let lists: [LeaveBehindList]
    let total: Int

    var body: some View {
        if lists.count + 1 <= Self.maximumSegments {
            picker.pickerStyle(.segmented)
        } else {
            picker.pickerStyle(.menu)
        }
    }

    private var picker: some View {
        Picker("Show", selection: $filter) {
            Text("All \(total)").tag(LeaveBehindFilter.all)
            ForEach(lists) { list in
                Text("\(list.name) \(list.domains.count)").tag(LeaveBehindFilter.list(list.id))
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}
