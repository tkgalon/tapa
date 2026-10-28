import SwiftUI

struct NoDescentLeftView: View {
    let summitEndsAt: Date?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No Descents Left This Week")
                    .font(.title3.bold())
                Group {
                    if let summitEndsAt {
                        let time = summitEndsAt.formatted(.dateTime.hour().minute())
                        Text("Summit Mode ends at \(time). Descents come back on Monday.")
                    } else {
                        Text("Descents come back on Monday.")
                    }
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("OK", action: close)
                    .buttonStyle(.borderedProminent)
                    .tint(.glacier)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
    }
}
