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

    var id: String { key }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        key = try container.decodeLossyString(forKey: .key)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case type
    }
}

struct PlexLibrarySection: Identifiable {
    let id: String
    let title: String
    let type: String
    let items: [PlexMediaItem]
}

struct PlexMediaItem: Decodable, Identifiable, Hashable {
    let ratingKey: String
    let title: String
    let art: String?
    let thumb: String?
    let parentThumb: String?
    let grandparentThumb: String?

    var id: String { ratingKey }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ratingKey = try container.decodeLossyString(forKey: .ratingKey)
        title = try container.decode(String.self, forKey: .title)
        art = try container.decodeIfPresent(String.self, forKey: .art)
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
        parentThumb = try container.decodeIfPresent(String.self, forKey: .parentThumb)
        grandparentThumb = try container.decodeIfPresent(String.self, forKey: .grandparentThumb)
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
