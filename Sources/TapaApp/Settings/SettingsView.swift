import ServiceManagement
import SwiftUI
import TapaCore

/// The few things worth changing rarely: starting at login, the time in the menu bar, the Descents
/// left, and the way to remove Tapa.
struct SettingsView: View {
    @Environment(DaemonStore.self) private var daemon
    @AppStorage(MenuBarPreferences.showsTimeKey) private var showsTimeInMenuBar = true

    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var needsLoginApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var isConfirmingUninstall = false
    @State private var isUninstalling = false
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: Binding(get: { opensAtLogin }, set: { setOpensAtLogin($0) }))
                if needsLoginApproval {
                    LabeledContent {
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    } label: {
                        Text("Allow Tapa in System Settings to finish.")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Show Time in Menu Bar", isOn: $showsTimeInMenuBar)
            }

            Section {
                LabeledContent("Descents") {
                    Text(descentsSummary)
                }
            } header: {
                Text("Summit Mode")
            } footer: {
                Text("A Descent ends Summit Mode early. The count resets every Monday at 00.00.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(PhotoCredit.all) { credit in
                    LabeledContent(credit.screen) {
                        Text(verbatim: "\(credit.photographer), Unsplash")
                    }
                }
            } header: {
                Text("Photos")
            } footer: {
                Link("Unsplash License", destination: URL(string: "https://unsplash.com/license")!)
                    .font(.callout)
            }

            Section {
                LabeledContent("Background Service") {
                    Text(serviceStatus)
                }
                LabeledContent("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
                LabeledContent("Remove Tapa from This Mac") {
                    Button("Uninstall…", role: .destructive) { isConfirmingUninstall = true }
                        .disabled(isSummitRunning || isUninstalling)
                }
            } header: {
                Text("Tapa")
            } footer: {
                if isSummitRunning {
                    Text("Tapa can be uninstalled once Summit Mode ends.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Uninstall Tapa?", isPresented: $isConfirmingUninstall) {
            Button("Uninstall", role: .destructive, action: uninstall)
        } message: {
            Text("""
                This removes the background service, every block, your lists and Rituals, and Tapa \
                itself. You'll be asked for an administrator password.
                """)
        }
        .alert("Couldn't Change Settings", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var isSummitRunning: Bool {
        daemon.snapshot?.mode == .summit
    }

    private var descentsSummary: String {
        guard let remaining = daemon.snapshot?.descentsRemaining else { return "–" }
        return String(localized: "\(remaining) of \(DescentLedger.defaultQuota) left this week")
    }

    private var serviceStatus: String {
        switch daemon.connection {
        case .connecting:
            String(localized: "Connecting…")
        case .notInstalled:
            String(localized: "Not installed")
        case .unreachable:
            String(localized: "Not responding")
        case .connected where daemon.snapshot?.isClockVerified == true:
            String(localized: "Running · Clock verified")
        case .connected:
            String(localized: "Running · Verifying the clock")
        }
    }

    private func setOpensAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            failure = error.localizedDescription
            isShowingFailure = true
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
        needsLoginApproval = SMAppService.mainApp.status == .requiresApproval
    }

    private func uninstall() {
        isUninstalling = true
        Task {
            defer { isUninstalling = false }
            // Summit Mode may have started since the button was drawn.
            await daemon.refresh()
            guard !isSummitRunning else {
                failure = String(localized: "Tapa can be uninstalled once Summit Mode ends.")
                isShowingFailure = true
                return
            }
            do {
                try Uninstaller.run()
                NSApp.terminate(nil)
            } catch Uninstaller.Failure.cancelled {
                return
            } catch {
                failure = error.localizedDescription
                isShowingFailure = true
            }
        }
    }
}
