import CoreGraphics
import Foundation

struct MediaArtworkSet: Hashable {
    let posterURL: URL?
    let landscapeURL: URL?
    let backdropURL: URL?

    func url(for style: MediaArtworkStyle) -> URL? {
        switch style {
        case .poster:
            posterURL
        case .landscape:
            landscapeURL
        }
    }
}

enum MediaArtworkStyle: Hashable {
    case poster
    case landscape

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .landscape:
            return 16 / 9
        }
    }

    var width: CGFloat {
        switch self {
        case .poster:
            return 480
        case .landscape:
            return 620
        }
    }

    var imageRequestWidth: Int {
        Int(width * 2)
    }

    var imageRequestHeight: Int {
        Int(CGFloat(imageRequestWidth) / aspectRatio)
    }

    func fittedSize(in bounds: CGSize) -> CGSize {
        let width = min(width, bounds.width)
        let height = width / aspectRatio

        if height <= bounds.height {
            return CGSize(width: width, height: height)
        }

        let fittedHeight = bounds.height
        return CGSize(width: fittedHeight * aspectRatio, height: fittedHeight)
    }
}
