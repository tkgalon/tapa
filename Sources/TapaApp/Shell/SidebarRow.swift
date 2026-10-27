import SwiftUI

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label {
                Text(item.title)
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(Color.glacier)
                    .frame(width: 20)
            }
            .fontWeight(isSelected ? .medium : .regular)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.glacier.opacity(0.14) : .clear, in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
