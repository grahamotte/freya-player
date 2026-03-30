import Foundation

struct PlexConnectionSummary {
    let serverID: String
    let serverName: String
    let serverURL: String
    let serverToken: String
    let accountName: String
    let libraries: [PlexLibrarySection]
}

struct PlexLibrary: Decodable, Identifiable {
    let key: String
    let title: String
    let type: String
    let agent: String?

    var id: String { key }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        key = try container.decodeLossyString(forKey: .key)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case type
        case agent
    }
}

struct PlexLibrarySection: Identifiable {
    let id: String
    let title: String
    let type: String
    let agent: String?
    let items: [PlexMediaItem]
}

struct PlexMediaItem: Decodable, Identifiable, Hashable {
    let ratingKey: String
    let title: String
    let summary: String?
    let year: Int?
    let duration: Int?
    let contentRating: String?
    let art: String?
    let thumb: String?
    let parentThumb: String?
    let grandparentThumb: String?

    var id: String { ratingKey }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ratingKey = try container.decodeLossyString(forKey: .ratingKey)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeLossyStringIfPresent(forKey: .summary)
        year = try container.decodeLossyIntIfPresent(forKey: .year)
        duration = try container.decodeLossyIntIfPresent(forKey: .duration)
        contentRating = try container.decodeLossyStringIfPresent(forKey: .contentRating)
        art = try container.decodeIfPresent(String.self, forKey: .art)
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
        parentThumb = try container.decodeIfPresent(String.self, forKey: .parentThumb)
        grandparentThumb = try container.decodeIfPresent(String.self, forKey: .grandparentThumb)
    }

    var synopsis: String {
        let trimmed = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No description available." : trimmed
    }

    var runtimeText: String? {
        guard let duration else { return nil }

        let minutes = duration / 60_000
        guard minutes > 0 else { return nil }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    func artworkURL(baseURL: String, token: String, width: Int, height: Int, preferCoverArt: Bool = false) -> URL? {
        let imagePath = if preferCoverArt {
            art ?? thumb ?? parentThumb ?? grandparentThumb
        } else {
            thumb ?? parentThumb ?? grandparentThumb ?? art
        }

        guard let imagePath,
              var components = URLComponents(string: "\(baseURL)/photo/:/transcode") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "url", value: imagePath),
            URLQueryItem(name: "width", value: String(width)),
            URLQueryItem(name: "height", value: String(height)),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "upscale", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]

        return components.url
    }

    private enum CodingKeys: String, CodingKey {
        case ratingKey
        case title
        case summary
        case year
        case duration
        case contentRating
        case art
        case thumb
        case parentThumb
        case grandparentThumb
    }
}

struct PlexPin: Decodable {
    let id: Int
    let code: String
    let authToken: String?
    let expiresIn: Int?
}
