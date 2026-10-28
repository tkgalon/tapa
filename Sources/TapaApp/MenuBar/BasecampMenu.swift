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
        Text("⛺️ Basecamp")
        Divider()

        Section("Begin Ascent") {
            ForEach(Array(EndTimeChoices.after(now).prefix(3).enumerated()), id: \.element) { index, time in
                Button(title(until: time, now: now, isFirst: index == 0)) { begin(until: time) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                    .disabled(listIDs.isEmpty)
            }
            Button("Choose Time…") {
                router.selection = .basecamp
                openTapa()
            }
        }
        Divider()

        Picker("Mode", selection: $mode) {
            Text("🥾 Trail").tag(SessionMode.trail)
            Text("🏔️ Summit Mode").tag(SessionMode.summit)
        }
        .pickerStyle(.inline)

        Menu("Leave Behind: \(listSummary)") {
            if daemon.config.leaveBehindLists.isEmpty {
                Button("Create a List in Leave Behind…") {
                    router.selection = .leaveBehind
                    openTapa()
                }
            }
            ForEach(daemon.config.leaveBehindLists) { list in
                Toggle(list.name, isOn: Binding(get: { listIDs.contains(list.id) }, set: { setList(list.id, $0) }))
            }
        }
        Divider()

        if let upcoming = daemon.upNext(after: now) {
            Text("Next Ritual: \(upcoming.ritual.name) \(upcoming.interval.start.ritualStart(from: now))")
        }
        Text("^[\(daemon.snapshot?.descentsRemaining ?? 0) Descent](inflect: true) left this week")
    }

    /// The lists chosen last time that still exist, or the first list when none do.
    private var listIDs: Set<LeaveBehindList.ID> {
        let lists = daemon.config.leaveBehindLists
        let stored = Set(storedListIDs.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        let chosen = Set(lists.map(\.id)).intersection(stored)
        return chosen.isEmpty ? Set(lists.prefix(1).map(\.id)) : chosen
    }

    private var listSummary: String {
        let names = daemon.config.leaveBehindLists.filter { listIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? String(localized: "None") : names.formatted(.list(type: .and))
    }

    private func setList(_ id: LeaveBehindList.ID, _ isOn: Bool) {
        var ids = listIDs
        ids[contains: id] = isOn
        storedListIDs = ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    /// "Until 10.00 · 18 min" for the nearest hour, so a short Ascent is obvious.
    private func title(until time: Date, now: Date, isFirst: Bool) -> String {
        let until = String(localized: "Until \(time.formatted(.dateTime.hour().minute()))")
        guard isFirst else { return until }
        let length = Duration.seconds(time.timeIntervalSince(now))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return "\(until) · \(length)"
    }

    private func begin(until endAt: Date) {
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
