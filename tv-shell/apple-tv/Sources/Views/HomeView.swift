import SwiftUI

public struct HomeView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var cloud = CloudSyncService.shared

    @State private var currentTime: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activePlaylist: Playlist? {
        appState.playlists.first(where: { $0.id == appState.activePlaylistId }) ?? appState.playlists.first
    }

    public var body: some View {
        ZStack {
            // Background: Deep Obsidian / Charcoal (#0A0B0E)
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ==========================================
                // TOP BAR: Minimal Monochrome Brand + Status
                // ==========================================
                HStack(alignment: .center) {
                    // Minimal Monochrome Logo
                    HStack(spacing: 10) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("YESXTREAM")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(2.5)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Active Playlist Pill + Clock
                    HStack(spacing: 16) {
                        if let pl = activePlaylist {
                            HStack(spacing: 8) {
                                // Tiny Apple System Green #30D158 Active Status Dot
                                Circle()
                                    .fill(Color(red: 0.188, green: 0.820, blue: 0.345))
                                    .frame(width: 8, height: 8)

                                Text("\(pl.name.cleanedIptvTitle) • \(pl.type == .xtream ? "XTREAM" : "M3U")")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }

                        // Live Clock
                        Text(currentTime)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 50)
                .padding(.top, 40)
                .padding(.bottom, 20)

                Spacer()

                // ==========================================
                // CENTER ROW: 4 Monochrome Glass Cards
                // ==========================================
                HStack(spacing: 28) {
                    HomeHeroCard(
                        title: "Live TV",
                        subtitle: "\(appState.channels.count) Channels",
                        icon: "tv",
                        badge: appState.channels.isEmpty ? nil : "\(appState.channels.count)",
                        action: {
                            appState.currentDestination = .liveTV
                        }
                    )

                    HomeHeroCard(
                        title: "Movies",
                        subtitle: "\(appState.vodMovies.count) Films",
                        icon: "film",
                        badge: appState.vodMovies.isEmpty ? nil : "\(appState.vodMovies.count)",
                        action: {
                            appState.currentDestination = .movies
                        }
                    )

                    HomeHeroCard(
                        title: "Series",
                        subtitle: "\(appState.seriesList.count) Series",
                        icon: "play.tv",
                        badge: appState.seriesList.isEmpty ? nil : "\(appState.seriesList.count)",
                        action: {
                            appState.currentDestination = .series
                        }
                    )

                    HomeHeroCard(
                        title: "Playlists",
                        subtitle: "\(appState.playlists.count) Configured",
                        icon: "list.bullet.rectangle",
                        badge: "\(appState.playlists.count)",
                        action: {
                            appState.currentDestination = .playlists
                        }
                    )
                }
                .padding(.horizontal, 50)

                Spacer()

                // ==========================================
                // BOTTOM UTILITY ROW: 3 Small Glass Circles
                // ==========================================
                HStack(spacing: 32) {
                    HomeUtilityCircleButton(
                        icon: "arrow.clockwise",
                        label: "Sync",
                        action: {
                            Task {
                                await cloud.syncDevice()
                                await appState.loadActivePlaylistCatalog(forceRefresh: true)
                            }
                        }
                    )

                    HomeUtilityCircleButton(
                        icon: "magnifyingglass",
                        label: "Search",
                        action: {
                            appState.currentDestination = .search
                        }
                    )

                    HomeUtilityCircleButton(
                        icon: "gearshape",
                        label: "Settings",
                        action: {
                            appState.currentDestination = .settings
                        }
                    )
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            updateClock()
        }
        .onReceive(timer) { _ in
            updateClock()
        }
    }

    private func updateClock() {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        currentTime = df.string(from: Date())
    }
}

// MARK: - Monochrome Glass Hero Card (tvOS Spec)
struct HomeHeroCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    // Crisp pure white SF Symbol icon at 80% opacity
                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                    Spacer()

                    if let b = badge {
                        Text(b)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.card)
    }
}

// MARK: - Home Utility Circle Button (58pt x 58pt)
struct HomeUtilityCircleButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}
