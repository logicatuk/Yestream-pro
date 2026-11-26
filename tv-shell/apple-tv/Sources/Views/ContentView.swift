import SwiftUI

public struct ContentView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared
    @State private var showingPlaylistsWhileExpired: Bool = false

    public var body: some View {
        Group {
            if cloud.registration?.isExpired == true && !showingPlaylistsWhileExpired {
                DeviceExpiredView(onOpenPlaylists: {
                    showingPlaylistsWhileExpired = true
                })
            } else if cloud.registration?.isExpired == true && showingPlaylistsWhileExpired {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            showingPlaylistsWhileExpired = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Back to Activation")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(height: 38)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("DEVICE EXPIRED • MANAGE PLAYLISTS")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    .background(Color(red: 0.04, green: 0.06, blue: 0.11))

                    PlaylistsView()
                }
                .background(Color(red: 0.04, green: 0.06, blue: 0.11).ignoresSafeArea())
            } else {
                ZStack {
                    TabView(selection: $appState.selectedTab) {
                        HomeView()
                            .tabItem {
                                Label("Home", systemImage: "house")
                            }
                            .tag(0)

                        LiveTVView()
                            .tabItem {
                                Label("Live TV", systemImage: "tv")
                            }
                            .tag(1)

                        MoviesView()
                            .tabItem {
                                Label("Movies", systemImage: "film")
                            }
                            .tag(2)

                        SeriesView()
                            .tabItem {
                                Label("Series", systemImage: "play.tv")
                            }
                            .tag(3)

                        EPGGuideView()
                            .tabItem {
                                Label("EPG Guide", systemImage: "calendar.badge.clock")
                            }
                            .tag(4)

                        PlaylistsView()
                            .tabItem {
                                Label("Playlists", systemImage: "list.bullet.rectangle")
                            }
                            .tag(5)

                        FavoritesView()
                            .tabItem {
                                Label("Favorites", systemImage: "heart")
                            }
                            .tag(6)

                        SearchView()
                            .tabItem {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                            .tag(7)

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tag(8)
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
            }
        }
        .onAppear {
            if appState.playlists.isEmpty {
                appState.selectedTab = 5
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
