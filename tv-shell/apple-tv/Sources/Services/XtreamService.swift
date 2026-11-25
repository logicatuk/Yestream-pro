import Foundation

public struct XtreamCategory: Identifiable, Codable {
    public let category_id: String
    public let category_name: String
    public var id: String { category_id }
}

public struct VodDetail: Codable {
    public let tmdbId: String?
    public let name: String?
    public let backdropUrl: String?
    public let posterUrl: String?
    public let releaseDate: String?
    public let durationMinutes: String?
    public let director: String?
    public let cast: String?
    public let plot: String?
    public let genre: String?
    public let rating: String?
    public let streamUrl: String
}

public struct EpgProgram: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let start: String
    public let end: String
    public let startTimestamp: Double?
    public let stopTimestamp: Double?

    public var progress: Double {
        guard let s = startTimestamp, let e = stopTimestamp, e > s else { return 0.0 }
        let now = Date().timeIntervalSince1970
        if now <= s { return 0.0 }
        if now >= e { return 1.0 }
        return (now - s) / (e - s)
    }

    public var formattedTimeRange: String {
        let sTime = formatTime(start)
        let eTime = formatTime(end)
        if !sTime.isEmpty && !eTime.isEmpty {
            return "\(sTime) - \(eTime)"
        }
        return ""
    }

    private func formatTime(_ raw: String) -> String {
        let parts = raw.split(separator: " ")
        if parts.count >= 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 2 {
                return "\(timeParts[0]):\(timeParts[1])"
            }
        }
        return raw
    }
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

    public static func fetchChannelEpg(serverUrl: String, user: String, pass: String, streamId: String) async -> [EpgProgram] {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)
        guard let url = URL(string: "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_short_epg&stream_id=\(streamId)") else {
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let listings = json["epg_listings"] as? [[String: Any]] else {
                return []
            }
            return listings.compactMap { dict in
                let rawTitle = dict["title"] as? String ?? ""
                let rawDesc = dict["description"] as? String ?? ""
                let id = dict["id"] as? String ?? UUID().uuidString
                let start = dict["start"] as? String ?? ""
                let end = dict["end"] as? String ?? ""
                let sTs = (dict["start_timestamp"] as? String).flatMap(Double.init) ?? (dict["start_timestamp"] as? Double)
                let eTs = (dict["stop_timestamp"] as? String).flatMap(Double.init) ?? (dict["stop_timestamp"] as? Double)

                let title = decodeBase64OrPlain(rawTitle)
                let desc = decodeBase64OrPlain(rawDesc)

                return EpgProgram(
                    id: id,
                    title: title,
                    description: desc,
                    start: start,
                    end: end,
                    startTimestamp: sTs,
                    stopTimestamp: eTs
                )
            }
        } catch {
            return []
        }
    }

    public static func decodeBase64OrPlain(_ text: String) -> String {
        if let data = Data(base64Encoded: text), let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
            return decoded
        }
        return text
    }

    public static func fetchVodDetails(serverUrl: String, user: String, pass: String, streamId: String) async -> VodDetail? {
        let base = normalizeServerUrl(serverUrl)
        let (u, p) = extractCredentials(from: serverUrl, user: user, pass: pass)
        guard let url = URL(string: "\(base)/player_api.php?username=\(u)&password=\(p)&action=get_vod_info&vod_id=\(streamId)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let info = json["info"] as? [String: Any] else {
                return nil
            }
            let movieData = json["movie_data"] as? [String: Any]
            let ext = (movieData?["container_extension"] as? String) ?? "mp4"
            let playUrl = "\(base)/movie/\(u)/\(p)/\(streamId).\(ext)"

            let tmdbId = String(describing: info["tmdb_id"] ?? "")
            let name = info["name"] as? String ?? info["o_name"] as? String
            let poster = info["movie_image"] as? String ?? info["cover_big"] as? String
            let backdrop = (info["backdrop_path"] as? [String])?.first ?? info["cover_big"] as? String
            let releaseDate = info["releasedate"] as? String
            let duration = String(describing: info["episode_run_time"] ?? "")
            let director = info["director"] as? String
            let cast = info["cast"] as? String ?? info["actors"] as? String
            let plot = info["plot"] as? String ?? info["description"] as? String
            let genre = info["genre"] as? String
            let rating = String(describing: info["rating"] ?? "")

            return VodDetail(
                tmdbId: tmdbId.isEmpty ? nil : tmdbId,
                name: name,
                backdropUrl: backdrop,
                posterUrl: poster,
                releaseDate: releaseDate,
                durationMinutes: duration.isEmpty ? nil : duration,
                director: director,
                cast: cast,
                plot: plot,
                genre: genre,
                rating: rating.isEmpty ? nil : rating,
                streamUrl: playUrl
            )
        } catch {
            return nil
        }
    }
}
