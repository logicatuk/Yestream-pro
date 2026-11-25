import Foundation

public enum PlaylistType: String, Codable {
    case xtream = "xtream"
    case m3u = "m3u"
}

public struct Playlist: Identifiable, Codable {
    public let id: String
    public var name: String
    public var type: PlaylistType
    public var url: String
    public var username: String?
    public var password: String?

    public init(id: String = UUID().uuidString, name: String, type: PlaylistType, url: String, username: String? = nil, password: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.username = username
        self.password = password
    }
}

public enum MediaKind: String, Codable {
    case live = "live"
    case movie = "movie"
    case series = "series"
    case episode = "episode"
}

public struct MediaItem: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let kind: MediaKind
    public let streamUrl: String
    public let logoUrl: String?
    public let categoryId: String?
    public let categoryName: String?
    public let epgChannelId: String?

    public init(id: String, title: String, kind: MediaKind, streamUrl: String, logoUrl: String? = nil, categoryId: String? = nil, categoryName: String? = nil, epgChannelId: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.streamUrl = streamUrl
        self.logoUrl = logoUrl
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.epgChannelId = epgChannelId
    }
}
