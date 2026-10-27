import SwiftUI
import TapaCore

/// Mode, end time and Leave Behind lists, then Begin Ascent. Summit Mode goes through the Oath.
struct AscentBar: View {
    @Environment(DaemonStore.self) private var daemon

    @State private var mode = SessionMode.summit
    @State private var endTimes: [Date]
    @State private var endAt: Date
    @State private var listIDs: Set<LeaveBehindList.ID> = []
    @State private var pendingOath: PendingOath?
    @State private var failure: String?
    @State private var isShowingFailure = false

    init() {
        let choices = EndTimeChoices.after(.now)
        _endTimes = State(initialValue: choices)
        _endAt = State(initialValue: choices.dropFirst().first ?? choices.first ?? .now)
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("Mode", selection: $mode) {
                Text("🏔️ Summit Mode").tag(SessionMode.summit)
                Text("🥾 Trail").tag(SessionMode.trail)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Picker("Until", selection: $endAt) {
                ForEach(endTimes, id: \.self) { time in
                    Text(time, format: .dateTime.hour().minute()).tag(time)
                }
            }
            .fixedSize()

            Menu {
                ForEach(daemon.config.leaveBehindLists) { list in
                    Toggle(list.name, isOn: $listIDs[contains: list.id])
                }
            } label: {
                Text(listSummary)
            }
            .fixedSize()

            Button("Begin Ascent", action: begin)
                .buttonStyle(.borderedProminent)
                .tint(.glacier)
                .disabled(listIDs.isEmpty)
        }
        .controlSize(.large)
        .padding(8)
        .glassBackground(in: .capsule)
        .onChange(of: daemon.config.leaveBehindLists.map(\.id), initial: true) { _, ids in
            listIDs.formIntersection(ids)
            if listIDs.isEmpty, let first = ids.first {
                listIDs = [first]
            }
        }
        .sheet(item: $pendingOath) { pending in
            OathSheet(request: pending.request)
        }
        .alert("Couldn't Begin Ascent", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var listSummary: String {
        let names = daemon.config.leaveBehindLists.filter { listIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? String(localized: "Choose Lists") : names.formatted(.list(type: .and))
    }

    private func begin() {
        let request = StartRequest(mode: mode, endAt: endAt, leaveBehindIDs: listIDs)
        guard mode == .trail else {
            pendingOath = PendingOath(request: request)
            return
        }
        Task {
            do {
                try await daemon.start(request)
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
