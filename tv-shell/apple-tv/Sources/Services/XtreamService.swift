import Foundation

public struct XtreamCategory: Identifiable, Codable {
    public let category_id: String
    public let category_name: String
    public var id: String { category_id }
}

public struct XtreamStream: Identifiable, Codable {
    public let num: Int?
    public let name: String
    public let stream_type: String?
    public let stream_id: Int
    public let stream_icon: String?
    public let category_id: String?

    public var id: String { "\(stream_id)" }
}

public class XtreamService {
    public static func fetchLiveStreams(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], channels: [MediaItem]) {
        let base = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let catUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_live_categories"
        let streamUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_live_streams"

        guard let catUrl = URL(string: catUrlStr), let streamUrl = URL(string: streamUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (streamData, _) = URLSession.shared.data(from: streamUrl)

        let categories = (try? JSONDecoder().decode([XtreamCategory].self, from: try await catData)) ?? []
        let rawStreams = (try? JSONDecoder().decode([XtreamStream].self, from: try await streamData)) ?? []

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        let channels = rawStreams.map { s in
            let playUrl = "\(base)/live/\(user)/\(pass)/\(s.stream_id).m3u8"
            return MediaItem(
                id: "\(s.stream_id)",
                title: s.name,
                kind: .live,
                streamUrl: playUrl,
                logoUrl: s.stream_icon,
                categoryId: s.category_id,
                categoryName: s.category_id.flatMap { categoryMap[$0] }
            )
        }

        return (categories, channels)
    }
}
