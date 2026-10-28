import SwiftUI
import TapaCore

/// A new Ritual, or changes to one. A Summit Mode Ritual that commits to something new goes through
/// the Oath before it's saved.
struct RitualEditor: View {
    let original: Ritual
    let isNew: Bool

    @Environment(DaemonStore.self) private var daemon
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var mode: SessionMode
    @State private var days: Set<Weekday>
    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var listIDs: Set<LeaveBehindList.ID>
    @State private var isTakingOath = false
    @State private var isConfirmingDelete = false
    @State private var failure: String?
    @State private var isShowingFailure = false

    init(ritual: Ritual, isNew: Bool) {
        original = ritual
        self.isNew = isNew
        _name = State(initialValue: ritual.name)
        _mode = State(initialValue: ritual.mode)
        _days = State(initialValue: ritual.days)
        _startsAt = State(initialValue: ritual.startTime.date())
        _endsAt = State(initialValue: ritual.endTime.date())
        _listIDs = State(initialValue: ritual.leaveBehindIDs)
    }

    var body: some View {
        Group {
            if isTakingOath {
                RitualOathView(ritual: draft) {
                    isTakingOath = false
                } swear: {
                    save(draft)
                }
            } else {
                form
            }
        }
        .alert("Couldn't Save the Ritual", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "New Ritual" : "Edit Ritual")
                .font(.title2.bold())
                .padding([.horizontal, .top], 20)

            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Work Time"))
                    LabeledContent("Mode") {
                        ModePicker(mode: $mode)
                            .fixedSize()
                    }
                    LabeledContent("Days") {
                        DayPicker(days: $days)
                    }
                }
                Section {
                    DatePicker("Starts", selection: $startsAt, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endsAt, displayedComponents: .hourAndMinute)
                } footer: {
                    Text(spanNote)
                        .font(.callout)
                        .foregroundStyle(isSpanValid ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                }
                Section("Leave Behind") {
                    if daemon.config.leaveBehindLists.isEmpty {
                        Text("Make a list in Leave Behind first.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(daemon.config.leaveBehindLists) { list in
                        Toggle(isOn: $listIDs[contains: list.id]) {
                            Text(list.name)
                            Text("^[\(list.domains.count) website](inflect: true)")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            buttons
                .padding(20)
        }
        .frame(width: 520, height: 540)
        .confirmationDialog("Delete \(original.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete Ritual", role: .destructive, action: delete)
        } message: {
            Text("It won't start again.")
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if !isNew {
                Button("Delete Ritual…", role: .destructive) { isConfirmingDelete = true }
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(needsOath ? "Continue to the Oath" : "Save") {
                if needsOath {
                    isTakingOath = true
                } else {
                    save(draft)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.glacier)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .controlSize(.large)
    }

    private var draft: Ritual {
        var ritual = original
        ritual.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        ritual.mode = mode
        ritual.days = days
        ritual.startTime = TimeOfDay(startsAt)
        ritual.endTime = TimeOfDay(endsAt)
        ritual.leaveBehindIDs = listIDs
        return ritual
    }

    private var canSave: Bool {
        let ritual = draft
        return !ritual.name.isEmpty && (try? ritual.validate()) != nil
    }

    private var isSpanValid: Bool {
        (Ritual.minimumSpanMinutes...Ritual.maximumSpanMinutes).contains(draft.spanMinutes)
    }

    private var spanNote: String {
        let ritual = draft
        guard isSpanValid else { return String(localized: "A Ritual lasts 15 minutes to 12 hours.") }
        let length = Duration.seconds(ritual.spanMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        return ritual.crossesMidnight
            ? String(localized: "Runs \(length), into the next morning.")
            : String(localized: "Runs \(length).")
    }

    /// Summit Mode asks for the Oath when it's new to this Ritual, or when its days, times or lists
    /// change. A rename, or a Ritual that's switched off, commits to nothing new.
    private var needsOath: Bool {
        let ritual = draft
        guard ritual.mode == .summit, ritual.enabled else { return false }
        guard !isNew, original.mode == .summit, original.enabled else { return true }
        return ritual.days != original.days
            || ritual.startTime != original.startTime
            || ritual.endTime != original.endTime
            || ritual.leaveBehindIDs != original.leaveBehindIDs
    }

    private func save(_ ritual: Ritual) {
        var updated = daemon.config
        updated.save(ritual)
        apply(updated)
    }

    private func delete() {
        var updated = daemon.config
        updated.rituals.removeAll { $0.id == original.id }
        apply(updated)
    }

    private func apply(_ updated: DaemonConfig) {
        Task {
            do {
                try await daemon.updateConfig(updated)
                dismiss()
            } catch {
                isTakingOath = false
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
