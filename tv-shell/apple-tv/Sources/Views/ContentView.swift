import SwiftUI

public struct ContentView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        ZStack {
            // Screen Switcher
            switch appState.currentDestination {
            case .home:
                HomeView()
                    .transition(.opacity)

            case .liveTV:
                LiveTVView()
                    .transition(.opacity)

            case .movies:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Movies")
                    MoviesView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }

            case .series:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Series")
                    SeriesView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }

            case .playlists:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Playlists")
                    PlaylistsView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }

            case .favorites:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Favorites")
                    FavoritesView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }

            case .search:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Search")
                    SearchView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }

            case .settings:
                VStack(spacing: 0) {
                    TopSectionNavBar(title: "Settings")
                    SettingsView()
                }
                .transition(.opacity)
                .onExitCommand {
                    appState.currentDestination = .home
                }
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
            // Auto register and sync on launch
            await cloud.registerDevice()
            if appState.activePlaylistId != nil && appState.channels.isEmpty {
                await appState.loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
    }
}

// MARK: - Top Section Navigation Bar (When outside Home)
struct TopSectionNavBar: View {
    let title: String
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack {
            Button(action: {
                appState.currentDestination = .home
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text("Home")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title.uppercased())
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white.opacity(0.75))

            Spacer()

            // Balance Spacer
            Color.clear.frame(width: 80, height: 1)
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.4))
    }
}
