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

public struct XtreamVodStream: Identifiable, Codable {
    public let num: Int?
    public let name: String
    public let stream_id: Int
    public let stream_icon: String?
    public let category_id: String?
    public let container_extension: String?
    public let rating: String?
    public let year: String?

    public var id: String { "\(stream_id)" }
}

public struct XtreamSeriesRaw: Identifiable, Codable {
    public let num: Int?
    public let name: String
    public let series_id: Int
    public let cover: String?
    public let plot: String?
    public let rating: String?
    public let category_id: String?

    public var id: String { "\(series_id)" }
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

    public static func fetchVodStreams(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], movies: [MediaItem]) {
        let base = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let catUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_vod_categories"
        let streamUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_vod_streams"

        guard let catUrl = URL(string: catUrlStr), let streamUrl = URL(string: streamUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (streamData, _) = URLSession.shared.data(from: streamUrl)

        let categories = (try? JSONDecoder().decode([XtreamCategory].self, from: try await catData)) ?? []
        let rawVod = (try? JSONDecoder().decode([XtreamVodStream].self, from: try await streamData)) ?? []

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        let movies = rawVod.map { m in
            let ext = m.container_extension ?? "mp4"
            let playUrl = "\(base)/movie/\(user)/\(pass)/\(m.stream_id).\(ext)"
            return MediaItem(
                id: "\(m.stream_id)",
                title: m.name,
                kind: .movie,
                streamUrl: playUrl,
                logoUrl: m.stream_icon,
                categoryId: m.category_id,
                categoryName: m.category_id.flatMap { categoryMap[$0] },
                rating: m.rating,
                year: m.year
            )
        }

        return (categories, movies)
    }

    public static func fetchSeries(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], series: [SeriesItem]) {
        let base = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let catUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_series_categories"
        let seriesUrlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_series"

        guard let catUrl = URL(string: catUrlStr), let seriesUrl = URL(string: seriesUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (seriesData, _) = URLSession.shared.data(from: seriesUrl)

        let categories = (try? JSONDecoder().decode([XtreamCategory].self, from: try await catData)) ?? []
        let rawSeries = (try? JSONDecoder().decode([XtreamSeriesRaw].self, from: try await seriesData)) ?? []

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        let series = rawSeries.map { s in
            SeriesItem(
                seriesId: s.series_id,
                title: s.name,
                coverUrl: s.cover,
                rating: s.rating,
                categoryId: s.category_id,
                categoryName: s.category_id.flatMap { categoryMap[$0] },
                plot: s.plot
            )
        }

        return (categories, series)
    }

    public static func fetchSeriesEpisodes(serverUrl: String, user: String, pass: String, seriesId: Int) async throws -> [EpisodeItem] {
        let base = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlStr = "\(base)/player_api.php?username=\(user)&password=\(pass)&action=get_series_info&series_id=\(seriesId)"

        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let episodesDict = json["episodes"] as? [String: [[String: Any]]] else {
            return []
        }

        var episodes: [EpisodeItem] = []
        for (seasonKey, epsList) in episodesDict {
            let seasonNum = Int(seasonKey) ?? 1
            for ep in epsList {
                guard let epId = ep["id"] as? Int ?? (ep["id"] as? String).flatMap(Int.init) else { continue }
                let epTitle = ep["title"] as? String ?? "Episode \(ep["episode_num"] ?? "")"
                let epNum = ep["episode_num"] as? Int ?? (ep["episode_num"] as? String).flatMap(Int.init) ?? 1
                let ext = ep["container_extension"] as? String ?? "mp4"
                let playUrl = "\(base)/series/\(user)/\(pass)/\(epId).\(ext)"
                let cover = ep["info"].flatMap { ($0 as? [String: Any])?["movie_image"] as? String }

                episodes.append(EpisodeItem(
                    episodeId: epId,
                    title: epTitle,
                    seasonNum: seasonNum,
                    episodeNum: epNum,
                    streamUrl: playUrl,
                    coverUrl: cover
                ))
            }
        }

        return episodes.sorted { ($0.seasonNum, $0.episodeNum) < ($1.seasonNum, $1.episodeNum) }
    }
}
