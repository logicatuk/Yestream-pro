import SwiftUI

public struct ContentView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
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

            // Sync / Catalog Loading HUD Overlay
            if appState.isSyncingCatalog {
                ZStack {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()

                    VStack(spacing: 24) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.6)

                        VStack(spacing: 10) {
                            Text(appState.catalogSyncStatus.isEmpty ? "Synchronisation de la liste de lecture" : appState.catalogSyncStatus)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text(appState.catalogSyncDetail)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                        }
                    }
                    .padding(40)
                    .frame(minWidth: 540, maxWidth: 680)
                    .background(Color(white: 0.16).opacity(0.95))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.5), radius: 24)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .task {
            if appState.playlists.isEmpty {
                appState.selectedTab = 5
            }
            // Auto register and sync on launch
            await cloud.registerDevice()
            if appState.activePlaylistId != nil && appState.channels.isEmpty {
                await appState.loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
    }
}
