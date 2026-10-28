import AppKit
import SwiftUI

/// A row in the menu bar panel that reads like a menu item: glacier when the pointer is over it,
/// with a value or shortcut on the right and an optional check on the left.
struct PanelButton: View {
    let title: Text
    var trailing: Text?
    /// `nil` leaves no room for a check, so rows without one line up with the panel's text.
    var isChecked: Bool?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(
        _ title: LocalizedStringKey,
        trailing: Text? = nil,
        isChecked: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.init(title: Text(title), trailing: trailing, isChecked: isChecked, action: action)
    }

    init(title: Text, trailing: Text? = nil, isChecked: Bool? = nil, action: @escaping () -> Void) {
        self.title = title
        self.trailing = trailing
        self.isChecked = isChecked
        self.action = action
    }

    var body: some View {
        let isHighlighted = isHovered && isEnabled
        Button(action: action) {
            HStack(spacing: 6) {
                if let isChecked {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .opacity(isChecked ? 1 : 0)
                        .frame(width: 12)
                }
                title
                Spacer(minLength: 12)
                if let trailing {
                    trailing
                        .foregroundStyle(
                            isHighlighted ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary)
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(isEnabled ? .primary : .secondary))
            .background(isHighlighted ? Color.glacier : .clear, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isChecked == true ? .isSelected : [])
    }
}

/// A small heading over a group of rows.
struct PanelHeading: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
    }
}

enum MenuBarPanel {
    /// Closes the panel after an action, as a menu would. A MenuBarExtra window has no dismiss
    /// action of its own, and the panel is the key window while it's open.
    @MainActor
    static func close() {
        NSApp.keyWindow?.close()
    }
}
