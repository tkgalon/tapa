import SwiftUI
import TapaCore

/// A Ritual's name, schedule, mode and lists, with a switch to turn it on or off.
struct RitualRow: View {
    let ritual: Ritual
    /// Its color in the week above.
    let color: Color
    let listNames: String
    let isRunning: Bool
    /// Running Summit Mode holds the Ritual until it ends.
    let isLocked: Bool
    let edit: () -> Void
    let setEnabled: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(ritual.name)
                                .fontWeight(.semibold)
                        }
                        Text(details)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityHint(isLocked ? "Locked until this Summit Mode ends" : "Edit")

            if isRunning {
                Label("Running", systemImage: isLocked ? "lock.fill" : "circle.fill")
                    .labelStyle(RunningLabelStyle())
                    .font(.callout)
                    .foregroundStyle(Color.glacier)
                    .help(isLocked ? "Summit Mode Rituals can't change until they end." : "")
            }

            Toggle(ritual.name, isOn: Binding(get: { ritual.enabled }, set: { setEnabled($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(.glacier)
                .disabled(isLocked)
        }
        .frame(minHeight: 56)
        .opacity(ritual.enabled ? 1 : 0.6)
        .contextMenu {
            Button("Edit…", action: edit)
                .disabled(isLocked)
        }
    }

    private var details: String {
        let mode = ritual.mode == .summit ? String(localized: "🏔️ Summit Mode") : String(localized: "Trail")
        return [ritual.schedule(), mode, listNames].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A small dot or lock before "Running".
private struct RunningLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .imageScale(.small)
                .font(.caption2)
            configuration.title
        }
    }
}
