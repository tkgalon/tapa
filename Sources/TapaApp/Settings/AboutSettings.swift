import AppKit
import SwiftUI

/// Who made Tapa, its version, and the credits for the photos it shows.
struct AboutSettings: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    Text("Tapa")
                        .font(.title2.weight(.semibold))
                    Text("A quieter path to focus.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("Version \(Self.version)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Built with love by tkgalon")
                        .font(.callout)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                ForEach(PhotoCredit.all) { credit in
                    LabeledContent(credit.screen) {
                        Text(verbatim: "\(credit.photographer), Unsplash")
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Credits")
            } footer: {
                HStack(spacing: 16) {
                    Link("Unsplash License", destination: Self.unsplashLicense)
                    Link("Tapa is free software under the GPL-3.0", destination: Self.gpl)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // Both addresses are fixed and well formed.
    private static let unsplashLicense = URL(string: "https://unsplash.com/license")!
    private static let gpl = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
}
