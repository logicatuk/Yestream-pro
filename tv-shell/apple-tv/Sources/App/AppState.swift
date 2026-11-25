import Foundation
import SwiftUI

@MainActor
public class AppState: ObservableObject {
    public static let shared = AppState()

    // Playlists
    @Published public var playlists: [Playlist] = []
    @Published public var activePlaylistId: String?

    // Live Channels
    @Published public var channels: [MediaItem] = []
    @Published public var categories: [XtreamCategory] = []
    @Published public var selectedCategory: String = ""
    @Published public var isLoadingChannels: Bool = false

    // Movies VOD
    @Published public var vodMovies: [MediaItem] = []
    @Published public var vodCategories: [XtreamCategory] = []
    @Published public var selectedVodCategory: String = ""
    @Published public var isLoadingVod: Bool = false

    // Series
    @Published public var seriesList: [SeriesItem] = []
    @Published public var seriesCategories: [XtreamCategory] = []
    @Published public var selectedSeriesCategory: String = ""
    @Published public var isLoadingSeries: Bool = false

    // Favorites & History
    @Published public var favorites: [MediaItem] = []
    @Published public var history: [MediaItem] = []

    // Player & Search
    @Published public var currentlyPlaying: MediaItem?
    @Published public var searchQuery: String = ""

    public init() {
        loadLocalPlaylists()
        loadFavoritesAndHistory()
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
            await loadChannelsForActivePlaylist()
            await loadVodForActivePlaylist()
            await loadSeriesForActivePlaylist()
        }
    }

    public func updatePlaylist(_ p: Playlist) {
        if let idx = playlists.firstIndex(where: { $0.id == p.id }) {
            playlists[idx] = p
            savePlaylists()
            if activePlaylistId == p.id {
                Task {
                    await loadChannelsForActivePlaylist()
                    await loadVodForActivePlaylist()
                    await loadSeriesForActivePlaylist()
                }
            }
        }
    }

    public func deletePlaylist(id: String) {
        playlists.removeAll(where: { $0.id == id })
        if activePlaylistId == id {
            activePlaylistId = playlists.first?.id
            Task {
                await loadChannelsForActivePlaylist()
                await loadVodForActivePlaylist()
                await loadSeriesForActivePlaylist()
            }
        }
        savePlaylists()
    }

    public func selectActivePlaylist(id: String) {
        guard activePlaylistId != id else { return }
        activePlaylistId = id
        savePlaylists()
        Task {
            await loadChannelsForActivePlaylist()
            await loadVodForActivePlaylist()
            await loadSeriesForActivePlaylist()
        }
    }

    public func loadChannelsForActivePlaylist() async {
        guard let active = playlists.first(where: { $0.id == activePlaylistId }) else { return }
        self.isLoadingChannels = true
        if active.type == .xtream, let user = active.username, let pass = active.password {
            do {
                let (cats, items) = try await XtreamService.fetchLiveStreams(serverUrl: active.url, user: user, pass: pass)
                self.categories = cats
                self.channels = items
                if let firstCat = cats.first, self.selectedCategory.isEmpty {
                    self.selectedCategory = firstCat.category_id
                }
            } catch {
                print("Failed to load Xtream channels: \(error)")
            }
        }
        self.isLoadingChannels = false
    }

    public func loadVodForActivePlaylist() async {
        guard let active = playlists.first(where: { $0.id == activePlaylistId }) else { return }
        self.isLoadingVod = true
        if active.type == .xtream, let user = active.username, let pass = active.password {
            do {
                let (cats, items) = try await XtreamService.fetchVodStreams(serverUrl: active.url, user: user, pass: pass)
                self.vodCategories = cats
                self.vodMovies = items
                if let firstCat = cats.first, self.selectedVodCategory.isEmpty {
                    self.selectedVodCategory = firstCat.category_id
                }
            } catch {
                print("Failed to load Xtream VOD: \(error)")
            }
        }
        self.isLoadingVod = false
    }

    public func loadSeriesForActivePlaylist() async {
        guard let active = playlists.first(where: { $0.id == activePlaylistId }) else { return }
        self.isLoadingSeries = true
        if active.type == .xtream, let user = active.username, let pass = active.password {
            do {
                let (cats, items) = try await XtreamService.fetchSeries(serverUrl: active.url, user: user, pass: pass)
                self.seriesCategories = cats
                self.seriesList = items
                if let firstCat = cats.first, self.selectedSeriesCategory.isEmpty {
                    self.selectedSeriesCategory = firstCat.category_id
                }
            } catch {
                print("Failed to load Xtream Series: \(error)")
            }
        }
        self.isLoadingSeries = false
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
