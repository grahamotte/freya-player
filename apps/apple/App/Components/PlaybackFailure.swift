import Foundation

struct PlaybackFailure: Identifiable {
    let id = UUID()
    let title = "Playback Failed"
    let message: String

    init(_ error: Error, summary: String = "Freya couldn't start this item.") {
        message = "\(summary)\n\nDetails\n\(Self.details(for: error))"
    }

    init(summary: String, details: String) {
        message = "\(summary)\n\nDetails\n\(details)"
    }

    private static func details(for error: Error) -> String {
        var messages: [String] = []
        var current: Error? = error

        for _ in 0 ..< 8 {
            guard let next = current else { break }
            let nsError = next as NSError
            [nsError.localizedDescription, nsError.localizedFailureReason, nsError.localizedRecoverySuggestion]
                .compactMap { $0 }
                .filter { !messages.contains($0) }
                .forEach { messages.append($0) }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? Error
        }

        return messages.joined(separator: "\n")
    }
}
