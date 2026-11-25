import Foundation

public struct XtreamCategory: Identifiable, Codable {
    public let category_id: String
    public let category_name: String
    public var id: String { category_id }
}

public class XtreamService {
    /// Normalizes server URL by extracting scheme + host + port and stripping /get.php, /player_api.php, etc.
    public static func normalizeServerUrl(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        guard let url = URL(string: trimmed), let host = url.host else {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let scheme = url.scheme ?? "http"
        let portPart = url.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(host)\(portPart)"
    }

    /// Extracts username and password from playlist URL parameters if not explicitly provided
    public static func extractCredentials(from raw: String, user: String?, pass: String?) -> (user: String, pass: String) {
        if let u = user, !u.isEmpty, let p = pass, !p.isEmpty {
            return (u, p)
        }
        guard let components = URLComponents(string: raw) else {
            return (user ?? "", pass ?? "")
        }
        let queryItems = components.queryItems ?? []
        let extractedUser = queryItems.first(where: { $0.name.lowercased() == "username" || $0.name.lowercased() == "user" })?.value ?? user ?? ""
        let extractedPass = queryItems.first(where: { $0.name.lowercased() == "password" || $0.name.lowercased() == "pass" })?.value ?? pass ?? ""
        return (extractedUser, extractedPass)
    }

    public static func fetchLiveStreams(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], channels: [MediaItem]) {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)

        let catUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_live_categories"
        let streamUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_live_streams"

        guard let catUrl = URL(string: catUrlStr), let streamUrl = URL(string: streamUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (streamData, _) = URLSession.shared.data(from: streamUrl)

        // Parse categories
        var categories: [XtreamCategory] = []
        if let catJson = (try? JSONSerialization.jsonObject(with: try await catData)) as? [[String: Any]] {
            categories = catJson.compactMap { dict in
                let id = String(describing: dict["category_id"] ?? "")
                let name = dict["category_name"] as? String ?? "General"
                guard !id.isEmpty else { return nil }
                return XtreamCategory(category_id: id, category_name: name)
            }
        }

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        // Parse streams with resilient JSON parsing
        var channels: [MediaItem] = []
        if let streamJson = (try? JSONSerialization.jsonObject(with: try await streamData)) as? [[String: Any]] {
            channels = streamJson.compactMap { s in
                guard let streamId = s["stream_id"] as? Int ?? (s["stream_id"] as? String).flatMap(Int.init) else { return nil }
                let name = s["name"] as? String ?? "Channel"
                let icon = s["stream_icon"] as? String
                let catId = (s["category_id"] as? String) ?? (s["category_id"] as? Int).map(String.init)
                let playUrl = "\(base)/live/\(u)/\(p)/\(streamId).m3u8"

                return MediaItem(
                    id: "\(streamId)",
                    title: name,
                    kind: .live,
                    streamUrl: playUrl,
                    logoUrl: icon,
                    categoryId: catId,
                    categoryName: catId.flatMap { categoryMap[$0] }
                )
            }
        }

        return (categories, channels)
    }

    public static func fetchVodStreams(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], movies: [MediaItem]) {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)

        let catUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_vod_categories"
        let streamUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_vod_streams"

        guard let catUrl = URL(string: catUrlStr), let streamUrl = URL(string: streamUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (streamData, _) = URLSession.shared.data(from: streamUrl)

        var categories: [XtreamCategory] = []
        if let catJson = (try? JSONSerialization.jsonObject(with: try await catData)) as? [[String: Any]] {
            categories = catJson.compactMap { dict in
                let id = String(describing: dict["category_id"] ?? "")
                let name = dict["category_name"] as? String ?? "Movies"
                guard !id.isEmpty else { return nil }
                return XtreamCategory(category_id: id, category_name: name)
            }
        }

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        var movies: [MediaItem] = []
        if let vodJson = (try? JSONSerialization.jsonObject(with: try await streamData)) as? [[String: Any]] {
            movies = vodJson.compactMap { m in
                guard let streamId = m["stream_id"] as? Int ?? (m["stream_id"] as? String).flatMap(Int.init) else { return nil }
                let name = m["name"] as? String ?? "Movie"
                let icon = m["stream_icon"] as? String
                let catId = (m["category_id"] as? String) ?? (m["category_id"] as? Int).map(String.init)
                let ext = m["container_extension"] as? String ?? "mp4"
                let playUrl = "\(base)/movie/\(u)/\(p)/\(streamId).\(ext)"
                let rating = String(describing: m["rating"] ?? "")
                let year = String(describing: m["year"] ?? "")

                return MediaItem(
                    id: "\(streamId)",
                    title: name,
                    kind: .movie,
                    streamUrl: playUrl,
                    logoUrl: icon,
                    categoryId: catId,
                    categoryName: catId.flatMap { categoryMap[$0] },
                    rating: rating.isEmpty ? nil : rating,
                    year: year.isEmpty ? nil : year
                )
            }
        }

        return (categories, movies)
    }

    public static func fetchSeries(serverUrl: String, user: String, pass: String) async throws -> (categories: [XtreamCategory], series: [SeriesItem]) {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)

        let catUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_series_categories"
        let seriesUrlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_series"

        guard let catUrl = URL(string: catUrlStr), let seriesUrl = URL(string: seriesUrlStr) else {
            throw URLError(.badURL)
        }

        async let (catData, _) = URLSession.shared.data(from: catUrl)
        async let (seriesData, _) = URLSession.shared.data(from: seriesUrl)

        var categories: [XtreamCategory] = []
        if let catJson = (try? JSONSerialization.jsonObject(with: try await catData)) as? [[String: Any]] {
            categories = catJson.compactMap { dict in
                let id = String(describing: dict["category_id"] ?? "")
                let name = dict["category_name"] as? String ?? "Series"
                guard !id.isEmpty else { return nil }
                return XtreamCategory(category_id: id, category_name: name)
            }
        }

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })

        var series: [SeriesItem] = []
        if let seriesJson = (try? JSONSerialization.jsonObject(with: try await seriesData)) as? [[String: Any]] {
            series = seriesJson.compactMap { s in
                guard let seriesId = s["series_id"] as? Int ?? (s["series_id"] as? String).flatMap(Int.init) else { return nil }
                let name = s["name"] as? String ?? "Series"
                let cover = s["cover"] as? String
                let rating = String(describing: s["rating"] ?? "")
                let catId = (s["category_id"] as? String) ?? (s["category_id"] as? Int).map(String.init)
                let plot = s["plot"] as? String

                return SeriesItem(
                    seriesId: seriesId,
                    title: name,
                    coverUrl: cover,
                    rating: rating.isEmpty ? nil : rating,
                    categoryId: catId,
                    categoryName: catId.flatMap { categoryMap[$0] },
                    plot: plot
                )
            }
        }

        return (categories, series)
    }

    public static func fetchSeriesEpisodes(serverUrl: String, user: String, pass: String, seriesId: Int) async throws -> [EpisodeItem] {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)

        let urlStr = "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_series_info&series_id=\(seriesId)"

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
                let playUrl = "\(base)/series/\(u)/\(p)/\(epId).\(ext)"
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
