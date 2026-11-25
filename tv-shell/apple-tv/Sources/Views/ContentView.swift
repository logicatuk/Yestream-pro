import SwiftUI

public struct ContentView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Int = 0

    public var body: some View {
        TabView(selection: $selectedTab) {
            LiveTVView()
                .tabItem {
                    Label("TV", systemImage: "tv")
                }
                .tag(0)

            PlaylistsView()
                .tabItem {
                    Label("Playlists", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .task {
            // Auto register and sync on launch
            await cloud.registerDevice()
            if appState.playlists.first != nil, appState.channels.isEmpty {
                await appState.loadChannelsForActivePlaylist()
            }
        }
    }
}
