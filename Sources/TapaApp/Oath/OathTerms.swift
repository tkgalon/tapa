import SwiftUI

/// When it runs, Leave Behind and Rest Stops, each with its icon.
struct OathTerms<When: View>: View {
    let websiteCount: Int
    @ViewBuilder let when: When

    var body: some View {
        VStack(spacing: 0) {
            when
            Divider()
            OathTermRow(title: "Leave Behind", systemImage: "nosign") {
                Text("^[\(websiteCount) website](inflect: true)")
            }
            Divider()
            OathTermRow(title: "Rest Stops", systemImage: "cup.and.saucer") {
                Text("Off")
            }
        }
        .padding(.horizontal, 12)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
    }
}
