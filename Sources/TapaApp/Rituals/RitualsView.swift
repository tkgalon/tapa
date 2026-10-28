import SwiftUI
import TapaCore

/// The Rituals that start Ascents on their own: the week at a glance, then each one with a switch.
struct RitualsView: View {
    @Environment(DaemonStore.self) private var daemon

    @State private var editing: EditingRitual?
    @State private var enabling: Ritual?
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        Group {
            if rituals.isEmpty {
                // The empty state centres in the whole content area, not in the space under the header.
                header
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .overlay { emptyState }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        RitualWeek(rituals: rituals) { ritual in
                            if !ritual.isLocked(by: daemon.snapshot) {
                                edit(ritual, isNew: false)
                            }
                        }
                        // Each minute, so "Ended for today" goes once the Ritual's time is over.
                        TimelineView(.everyMinute) { context in
                            list(at: context.date)
                        }
                        Text("Changing a Summit Mode Ritual asks for The Summit Oath again.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, -12)
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .sheet(item: $editing) { editing in
            RitualEditor(ritual: editing.ritual, isNew: editing.isNew)
        }
        .sheet(item: $enabling) { ritual in
            RitualOathView(ritual: ritual) {
                enabling = nil
            } swear: {
                enabling = nil
                setEnabled(true, for: ritual)
            }
        }
        .alert("Couldn't Change the Ritual", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var rituals: [Ritual] {
        daemon.config.rituals
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rituals")
                    .font(.largeTitle.bold())
                Text("Ascents that start on their own.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("New Ritual") { edit(newRitual(), isNew: true) }
                .buttonStyle(.borderedProminent)
                .tint(.glacier)
        }
        .frame(maxWidth: 760)
    }

    private func list(at now: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rituals.enumerated()), id: \.element.id) { index, ritual in
                RitualRow(
                    ritual: ritual,
                    color: .ritual(at: index),
                    listNames: listNames(for: ritual),
                    isRunning: ritual.isRunning(in: daemon.snapshot),
                    isLocked: ritual.isLocked(by: daemon.snapshot),
                    startsAgain: startsAgain(ritual, at: now)
                ) {
                    edit(ritual, isNew: false)
                } setEnabled: { isOn in
                    if isOn, ritual.mode == .summit {
                        enabling = ritual
                    } else {
                        setEnabled(isOn, for: ritual)
                    }
                }
                if ritual.id != rituals.last?.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 12)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Rituals Yet", systemImage: "calendar")
        } description: {
            Text("A Ritual starts an Ascent on its own, on the days and at the times you choose.")
        }
    }

    private func listNames(for ritual: Ritual) -> String {
        daemon.config.leaveBehindLists
            .filter { ritual.leaveBehindIDs.contains($0.id) }
            .map(\.name)
            .formatted(.list(type: .and))
    }

    private func startsAgain(_ ritual: Ritual, at now: Date) -> String? {
        guard ritual.hasEnded(in: daemon.snapshot, at: now),
              let next = ritual.nextOccurrence(after: now, calendar: .current)
        else { return nil }
        return next.start.ritualStart(from: now)
    }

    private func edit(_ ritual: Ritual, isNew: Bool) {
        editing = EditingRitual(ritual: ritual, isNew: isNew)
    }

    /// Trail by default, as at Basecamp, so Summit Mode is always a deliberate choice.
    private func newRitual() -> Ritual {
        Ritual(
            name: "",
            days: Weekday.weekdays,
            startTime: TimeOfDay(hour: 9) ?? .midnight,
            endTime: TimeOfDay(hour: 17) ?? .midnight,
            mode: .trail,
            leaveBehindIDs: Set(daemon.config.leaveBehindLists.prefix(1).map(\.id))
        )
    }

    private func setEnabled(_ isOn: Bool, for ritual: Ritual) {
        var changed = ritual
        changed.enabled = isOn
        var updated = daemon.config
        updated.save(changed)
        Task {
            do {
                try await daemon.updateConfig(updated)
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}

private struct EditingRitual: Identifiable {
    let ritual: Ritual
    let isNew: Bool

    var id: Ritual.ID { ritual.id }
}
