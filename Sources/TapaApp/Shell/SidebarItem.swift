import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case basecamp
    case leaveBehind
    case rituals
    case trailLog

    var id: Self { self }

    /// Shows a full-bleed photo that runs under the sidebar.
    var isImmersive: Bool {
        self == .basecamp
    }

    var title: LocalizedStringResource {
        switch self {
        case .basecamp: "Basecamp"
        case .leaveBehind: "Leave Behind"
        case .rituals: "Rituals"
        case .trailLog: "Trail Log"
        }
    }

    var systemImage: String {
        switch self {
        case .basecamp: "mountain.2"
        case .leaveBehind: "nosign"
        case .rituals: "calendar"
        case .trailLog: "chart.bar"
        }
    }
}
