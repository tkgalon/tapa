import SwiftUI
import TapaCore

/// Begin Ascent in one click, until one of the next whole hours. The mode and lists are remembered
/// between Ascents. Summit Mode still goes through the Oath, in the window.
struct BasecampMenu: View {
    let openTapa: () -> Void

    @Environment(DaemonStore.self) private var daemon
    @Environment(AppRouter.self) private var router

    /// Trail by default, so Summit Mode is always a deliberate choice.
    @AppStorage(MenuBarPreferences.quickModeKey) private var mode = SessionMode.trail
    @AppStorage(MenuBarPreferences.quickListsKey) private var storedListIDs = ""

    var body: some View {
        let now = Date.now
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(verbatim: "⛺️")
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Basecamp")
                        .fontWeight(.semibold)
                    Text("No Ascent right now")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            PanelDivider()

            PanelHeading("Begin Ascent")
            ForEach(Array(EndTimeChoices.after(now).prefix(3).enumerated()), id: \.element) { index, time in
                PanelButton(
                    title: title(until: time, now: now, isFirst: index == 0),
                    trailing: Text(verbatim: "⌘\(index + 1)")
                ) {
                    begin(until: time)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                .disabled(listIDs.isEmpty)
            }
            PanelButton("Choose Time…") {
                router.selection = .basecamp
                router.isChoosingEndTime = true
                openTapa()
            }
            PanelDivider()

            PanelHeading("Mode")
            PanelButton("🥾 Trail", isChecked: mode == .trail) { mode = .trail }
            PanelButton("🏔️ Summit Mode", isChecked: mode == .summit) { mode = .summit }
            PanelDivider()

            PanelHeading("Leave Behind")
            if daemon.config.leaveBehindLists.isEmpty {
                PanelButton("Create a List in Leave Behind…") {
                    router.selection = .leaveBehind
                    openTapa()
                }
            }
            ForEach(daemon.config.leaveBehindLists) { list in
                PanelButton(title: Text(list.name), isChecked: listIDs.contains(list.id)) {
                    setList(list.id, !listIDs.contains(list.id))
                }
            }
            PanelDivider()

            VStack(alignment: .leading, spacing: 4) {
                if let upcoming = daemon.upNext(after: now) {
                    Text("Next Ritual: \(upcoming.ritual.name) \(upcoming.interval.start.ritualStart(from: now))")
                }
                Text("^[\(daemon.snapshot?.descentsRemaining ?? 0) Descent](inflect: true) left this week")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    /// The lists chosen last time that still exist, or the first list when none do.
    private var listIDs: Set<LeaveBehindList.ID> {
        let lists = daemon.config.leaveBehindLists
        let stored = Set(storedListIDs.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        let chosen = Set(lists.map(\.id)).intersection(stored)
        return chosen.isEmpty ? Set(lists.prefix(1).map(\.id)) : chosen
    }

    private func setList(_ id: LeaveBehindList.ID, _ isOn: Bool) {
        var ids = listIDs
        ids[contains: id] = isOn
        storedListIDs = ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    /// "Until 10.00 · 18 min" for the nearest hour, so a short Ascent is obvious.
    private func title(until time: Date, now: Date, isFirst: Bool) -> Text {
        let until = Text("Until \(time.formatted(.dateTime.hour().minute()))")
        guard isFirst else { return until }
        let length = Duration.seconds(time.timeIntervalSince(now))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return Text("\(until) \(Text("· \(length)").foregroundStyle(.secondary))")
    }

    private func begin(until endAt: Date) {
        MenuBarPanel.close()
        let request = StartRequest(mode: mode, endAt: endAt, leaveBehindIDs: listIDs)
        guard mode == .trail else {
            router.takeOath(for: request)
            openTapa()
            return
        }
        Task {
            do {
                try await daemon.start(request)
            } catch {
                router.report(error)
                openTapa()
            }
        }
    }
}
