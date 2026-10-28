import AppKit
import SwiftUI

/// Photos bundled with the app. Unsplash stand-ins until Tapa has its own.
enum Photo: String, CaseIterable {
    case basecamp = "basecamp-tents"
    case summit = "clouds-over-peak"

    /// Where the photo appears, for its credit in Settings.
    var screen: LocalizedStringKey {
        switch self {
        case .basecamp: "Basecamp"
        case .summit: "Ascent"
        }
    }

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

/// Who took each bundled photo, for Settings. The Mist photos are served by the tracker, so they
/// aren't loaded here.
struct PhotoCredit: Identifiable {
    let screen: LocalizedStringKey
    let photographer: String

    var id: String { photographer }

    /// One row per screen. Mist picks among several photos, so its photographers share a row.
    static var all: [PhotoCredit] {
        let mist = ["Paul Pastourmatzis", "David Jusko", "Tobias Kebernik", "Tyler Lastovich"]
        return Photo.allCases.map { PhotoCredit(screen: $0.screen, photographer: $0.photographer) }
            + [PhotoCredit(screen: "Mist", photographer: mist.formatted(.list(type: .and)))]
    }
}
