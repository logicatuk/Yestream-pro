import Foundation
import SwiftUI

@MainActor
public class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var playlists: [Playlist] = []
    @Published public var activePlaylistId: String?
    @Published public var channels: [MediaItem] = []
    @Published public var categories: [XtreamCategory] = []
    @Published public var selectedCategory: String = ""
    @Published public var currentlyPlaying: MediaItem?
    @Published public var isLoadingChannels: Bool = false

    public init() {
        loadLocalPlaylists()
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
                if let firstCat = cats.first {
                    self.selectedCategory = firstCat.category_id
                }
            } catch {
                print("Failed to load Xtream channels: \(error)")
            }
        }
        self.isLoadingChannels = false
    }
}
