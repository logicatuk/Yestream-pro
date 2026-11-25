import Foundation
import SwiftUI

public struct CachedPlaylistCatalog: Codable {
    public let playlistId: String
    public let timestamp: Date
    public let categories: [XtreamCategory]
    public let channels: [MediaItem]
    public let vodCategories: [XtreamCategory]
    public let vodMovies: [MediaItem]
    public let seriesCategories: [XtreamCategory]
    public let seriesList: [SeriesItem]
}

@MainActor
public class AppState: ObservableObject {
    public static let shared = AppState()

    // Navigation
    @Published public var selectedTab: Int = 0

    // Catalog Synchronization & Caching HUD
    @Published public var isSyncingCatalog: Bool = false
    @Published public var catalogSyncStatus: String = ""
    @Published public var catalogSyncDetail: String = ""

    // Playlists
    @Published public var playlists: [Playlist] = []
    @Published public var activePlaylistId: String?

    // Live Channels
    @Published public var channels: [MediaItem] = []
    @Published public var categories: [XtreamCategory] = []
    @Published public var selectedCategory: String = "ALL"
    @Published public var isLoadingChannels: Bool = false

    // Movies VOD
    @Published public var vodMovies: [MediaItem] = []
    @Published public var vodCategories: [XtreamCategory] = []
    @Published public var selectedVodCategory: String = "ALL"
    @Published public var isLoadingVod: Bool = false

    // Series
    @Published public var seriesList: [SeriesItem] = []
    @Published public var seriesCategories: [XtreamCategory] = []
    @Published public var selectedSeriesCategory: String = "ALL"
    @Published public var isLoadingSeries: Bool = false

    // Favorites & History
    @Published public var favorites: [MediaItem] = []
    @Published public var history: [MediaItem] = []

    // EPG Cache
    @Published public var epgCache: [String: [EpgProgram]] = [:]

    // Player & Search
    @Published public var currentlyPlaying: MediaItem?
    @Published public var searchQuery: String = ""

    public func channelCount(for categoryId: String) -> Int {
        if categoryId == "FAVORITES" {
            return favorites.filter { $0.kind == .live }.count
        }
        if categoryId == "ALL" {
            return channels.count
        }
        return channels.filter { $0.categoryId == categoryId }.count
    }

    public func loadEpg(for channel: MediaItem) async {
        guard epgCache[channel.id] == nil else { return }
        guard let active = playlists.first(where: { $0.id == activePlaylistId }) else { return }
        let (u, p) = XtreamService.extractCredentials(from: active.url, user: active.username, pass: active.password)
        guard !u.isEmpty && !p.isEmpty else { return }
        let programs = await XtreamService.fetchChannelEpg(serverUrl: active.url, user: u, pass: p, streamId: channel.id)
        self.epgCache[channel.id] = programs
    }

    public init() {
        loadLocalPlaylists()
        loadFavoritesAndHistory()
    }

    private func cacheFileUrl(for playlistId: String) -> URL? {
        let safeId = playlistId.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("catalog_\(safeId).json")
    }

    public func loadLocalPlaylists() {
        if let data = UserDefaults.standard.data(forKey: "yestream_playlists"),
           let list = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = list
            self.activePlaylistId = UserDefaults.standard.string(forKey: "yestream_active_playlist_id") ?? list.first?.id
        }
    }

    public func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: "yestream_playlists")
        }
        UserDefaults.standard.set(activePlaylistId, forKey: "yestream_active_playlist_id")
    }

    public func addPlaylist(_ p: Playlist) {
        playlists.append(p)
        if activePlaylistId == nil {
            activePlaylistId = p.id
        }
        savePlaylists()
        Task {
            await CloudSyncService.shared.pushPlaylistToCloud(p)
            await loadActivePlaylistCatalog(forceRefresh: true)
        }
    }

    public func updatePlaylist(_ p: Playlist) {
        if let idx = playlists.firstIndex(where: { $0.id == p.id }) {
            playlists[idx] = p
            savePlaylists()
            Task {
                await CloudSyncService.shared.updatePlaylistOnCloud(p)
            }
            if activePlaylistId == p.id {
                Task {
                    await loadActivePlaylistCatalog(forceRefresh: true)
                }
            }
        }
    }

    public func deletePlaylist(id: String) {
        playlists.removeAll(where: { $0.id == id })
        if let cacheUrl = cacheFileUrl(for: id) {
            try? FileManager.default.removeItem(at: cacheUrl)
        }
        if activePlaylistId == id {
            activePlaylistId = playlists.first?.id
            Task {
                await loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
        savePlaylists()
        Task {
            await CloudSyncService.shared.deletePlaylistFromCloud(id: id)
        }
    }

    public func selectActivePlaylist(id: String, forceRefresh: Bool = false) {
        let isChangingPlaylist = (activePlaylistId != id)
        activePlaylistId = id
        savePlaylists()
        Task {
            await loadActivePlaylistCatalog(forceRefresh: forceRefresh || isChangingPlaylist)
            self.selectedTab = 0 // Switch to Live TV view
        }
    }

    // MARK: - Unified Catalog Loader with Local Cache
    public func loadActivePlaylistCatalog(forceRefresh: Bool = false) async {
        guard let active = playlists.first(where: { $0.id == activePlaylistId }) else { return }

        let (user, pass) = XtreamService.extractCredentials(from: active.url, user: active.username, pass: active.password)
        guard !user.isEmpty && !pass.isEmpty else { return }

        let cacheUrl = cacheFileUrl(for: active.id)

        // 1. FAST PATH: Check Local Device Library Cache
        if !forceRefresh, let cUrl = cacheUrl, FileManager.default.fileExists(atPath: cUrl.path) {
            self.isSyncingCatalog = true
            self.catalogSyncStatus = "Synchronisation de la liste de lecture"
            self.catalogSyncDetail = "Chargement du catalogue sauvegardé de cet appareil…\nLecture de la bibliothèque locale ; aucune donnée n'est téléchargée depuis le fournisseur."

            if let data = try? Data(contentsOf: cUrl),
               let cached = try? JSONDecoder().decode(CachedPlaylistCatalog.self, from: data) {
                self.categories = cached.categories
                self.channels = cached.channels
                self.vodCategories = cached.vodCategories
                self.vodMovies = cached.vodMovies
                self.seriesCategories = cached.seriesCategories
                self.seriesList = cached.seriesList

                if self.selectedCategory == "ALL" || !cached.categories.contains(where: { $0.category_id == self.selectedCategory }) {
                    self.selectedCategory = "ALL"
                }
                if self.selectedVodCategory == "ALL" || !cached.vodCategories.contains(where: { $0.category_id == self.selectedVodCategory }) {
                    self.selectedVodCategory = "ALL"
                }
                if self.selectedSeriesCategory == "ALL" || !cached.seriesCategories.contains(where: { $0.category_id == self.selectedSeriesCategory }) {
                    self.selectedSeriesCategory = "ALL"
                }

                print("Instantly loaded from local library cache: \(cached.channels.count) channels, \(cached.vodMovies.count) movies, \(cached.seriesList.count) series.")
                try? await Task.sleep(nanoseconds: 350_000_000) // Brief smooth HUD transition
                self.isSyncingCatalog = false
                return
            }
        }

        // 2. REMOTE PATH: Download from Provider Source
        self.isSyncingCatalog = true
        self.catalogSyncStatus = "Synchronisation de la liste de lecture"
        self.catalogSyncDetail = "Récupération des données de la liste depuis la source…"
        self.isLoadingChannels = true
        self.isLoadingVod = true
        self.isLoadingSeries = true

        do {
            // First load Live Channels and Categories so user gets instant TV
            let (liveCats, liveChannels) = try await XtreamService.fetchLiveStreams(serverUrl: active.url, user: user, pass: pass)
            self.categories = liveCats
            self.channels = liveChannels
            self.isLoadingChannels = false

            self.catalogSyncDetail = "Enregistrement des données de la liste localement… (\(liveChannels.count) chaînes)"

            // Concurrently fetch VOD and Series in background
            async let vodAsync = XtreamService.fetchVodStreams(serverUrl: active.url, user: user, pass: pass)
            async let seriesAsync = XtreamService.fetchSeries(serverUrl: active.url, user: user, pass: pass)

            let (vodCats, vodItems) = (try? await vodAsync) ?? ([], [])
            let (seriesCats, seriesItems) = (try? await seriesAsync) ?? ([], [])

            self.vodCategories = vodCats
            self.vodMovies = vodItems
            self.isLoadingVod = false

            self.seriesCategories = seriesCats
            self.seriesList = seriesItems
            self.isLoadingSeries = false

            // Save complete catalog to local disk cache for instant fast launch next time
            let catalog = CachedPlaylistCatalog(
                playlistId: active.id,
                timestamp: Date(),
                categories: liveCats,
                channels: liveChannels,
                vodCategories: vodCats,
                vodMovies: vodItems,
                seriesCategories: seriesCats,
                seriesList: seriesItems
            )
            if let data = try? JSONEncoder().encode(catalog), let cUrl = cacheUrl {
                try? data.write(to: cUrl, options: .atomic)
                print("Saved \(liveChannels.count) channels, \(vodItems.count) movies, \(seriesItems.count) series to disk cache.")
            }

            self.isSyncingCatalog = false
        } catch {
            print("Failed to sync catalog from provider: \(error)")
            self.catalogSyncDetail = "Erreur de connexion au fournisseur: \(error.localizedDescription)"
            self.isLoadingChannels = false
            self.isLoadingVod = false
            self.isLoadingSeries = false
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.isSyncingCatalog = false
        }
    }

    public func loadChannelsForActivePlaylist() async {
        await loadActivePlaylistCatalog(forceRefresh: false)
    }

    public func loadVodForActivePlaylist() async {
        if vodMovies.isEmpty {
            await loadActivePlaylistCatalog(forceRefresh: false)
        }
    }

    public func loadSeriesForActivePlaylist() async {
        if seriesList.isEmpty {
            await loadActivePlaylistCatalog(forceRefresh: false)
        }
    }

    // MARK: - Favorites & History
    private func loadFavoritesAndHistory() {
        if let favData = UserDefaults.standard.data(forKey: "yestream_favorites"),
           let favs = try? JSONDecoder().decode([MediaItem].self, from: favData) {
            self.favorites = favs
        }
        if let histData = UserDefaults.standard.data(forKey: "yestream_history"),
           let hists = try? JSONDecoder().decode([MediaItem].self, from: histData) {
            self.history = hists
        }
    }

    public func isFavorite(_ item: MediaItem) -> Bool {
        favorites.contains(where: { $0.id == item.id })
    }

    public func toggleFavorite(_ item: MediaItem) {
        if let idx = favorites.firstIndex(where: { $0.id == item.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(item, at: 0)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "yestream_favorites")
        }
    }

    public func addToHistory(_ item: MediaItem) {
        history.removeAll(where: { $0.id == item.id })
        history.insert(item, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "yestream_history")
        }
    }
}
