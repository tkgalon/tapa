import SwiftUI

struct OathTermRow<Value: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let value: Value

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: .rect(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            value
                .fontWeight(.semibold)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}
