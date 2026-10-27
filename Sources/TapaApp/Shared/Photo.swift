import AppKit
import SwiftUI

/// Photos bundled with the app. Unsplash stand-ins until Tapa has its own.
enum Photo: String, CaseIterable {
    case basecamp = "basecamp-tents"
    case summit = "clouds-over-peak"

    var photographer: String {
        switch self {
        case .basecamp: "Koushik Roy"
        case .summit: "Marek Piwnicki"
        }
    }

    @MainActor var image: Image {
        Self.images[self] ?? Image(systemName: "photo")
    }

    @MainActor private static let images: [Photo: Image] = Dictionary(
        uniqueKeysWithValues: allCases.compactMap { photo in
            guard let url = Bundle.main.url(forResource: photo.rawValue, withExtension: "jpg"),
                  let image = NSImage(contentsOf: url)
            else { return nil }
            return (photo, Image(nsImage: image))
        }
    )
}
