import Foundation

public struct SubDLSubtitleItem: Identifiable, Codable {
    public let id: String
    public let language: String
    public let releaseName: String
    public let url: String
    public let hearingImpaired: Bool
}

public class SubDLService {
    public static let apiKey = "subdl_Gb_Ujrf8yZqzgDmbnB4rD-ouf4BkMX5OWIFDWn4FzyQ"

    public static func searchSubtitles(title: String, tmdbId: Int? = nil, year: Int? = nil) async -> [SubDLSubtitleItem] {
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "film_name", value: title)
        ]
        if let tmdb = tmdbId {
            queryItems.append(URLQueryItem(name: "tmdb_id", value: "\(tmdb)"))
        }
        if let y = year {
            queryItems.append(URLQueryItem(name: "year", value: "\(y)"))
        }

        var components = URLComponents(string: "https://api.subdl.com/api/v1/subtitles")
        components?.queryItems = queryItems

        guard let url = components?.url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Bool, status,
                  let subs = json["subtitles"] as? [[String: Any]] else {
                return []
            }

            return subs.compactMap { sub in
                guard let rawUrl = sub["url"] as? String else { return nil }
                let downloadUrl = rawUrl.starts(with: "http") ? rawUrl : "https://dl.subdl.com\(rawUrl)"
                let lang = sub["language"] as? String ?? sub["lang"] as? String ?? "English"
                let release = sub["release_name"] as? String ?? sub["name"] as? String ?? title
                let hi = sub["hi"] as? Bool ?? false
                let id = sub["id"] as? String ?? "\(rawUrl.hashValue)"

                return SubDLSubtitleItem(
                    id: id,
                    language: lang,
                    releaseName: release,
                    url: downloadUrl,
                    hearingImpaired: hi
                )
            }
        } catch {
            return []
        }
    }

    public static func searchSeriesSubtitles(title: String, season: Int, episode: Int) async -> [SubDLSubtitleItem] {
        let epQuery = "\(title) S\(String(format: "%02d", season))E\(String(format: "%02d", episode))"
        let res = await searchSubtitles(title: epQuery)
        if !res.isEmpty { return res }
        return await searchSubtitles(title: title)
    }
}
