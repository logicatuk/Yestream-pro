import SwiftUI

public struct ContentView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Int = AppState.shared.playlists.isEmpty ? 5 : 0

    public var body: some View {
        TabView(selection: $selectedTab) {
            LiveTVView()
                .tabItem {
                    Label("TV", systemImage: "tv")
                }
                .tag(0)

            MoviesView()
                .tabItem {
                    Label("Movies", systemImage: "film")
                }
                .tag(1)

            SeriesView()
                .tabItem {
                    Label("Series", systemImage: "play.tv")
                }
                .tag(2)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .tag(3)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(4)

            PlaylistsView()
                .tabItem {
                    Label("Playlists", systemImage: "list.bullet.rectangle")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(6)
        }
        .task {
            // Auto register and sync on launch
            await cloud.registerDevice()
            if appState.playlists.first != nil, appState.channels.isEmpty {
                await appState.loadChannelsForActivePlaylist()
                await appState.loadVodForActivePlaylist()
                await appState.loadSeriesForActivePlaylist()
            }
        }
    }
}
