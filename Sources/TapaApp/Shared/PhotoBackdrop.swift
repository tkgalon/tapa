import SwiftUI

/// A full-bleed photo, darkened at the top so white text reads over the sky. Its credit is in
/// Settings.
struct PhotoBackdrop: View {
    let photo: Photo

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                photo.image
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.11, blue: 0.23).opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
