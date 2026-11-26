import SwiftUI

public struct HomeView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var cloud = CloudSyncService.shared

    private var activePlaylist: Playlist? {
        appState.playlists.first(where: { $0.id == appState.activePlaylistId }) ?? appState.playlists.first
    }

    private var macAddress: String {
        cloud.registration?.mac ?? "DA:E5:4A:7C:18:3F"
    }

    private var planStatusText: String {
        let plan = cloud.registration?.plan ?? "PRO"
        let status = (cloud.registration?.status ?? "active").uppercased()
        return "\(status) • \(plan)"
    }

    private var expirationString: String {
        if let exp = cloud.registration?.expiresAt {
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: exp) {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yyyy"
                return df.string(from: date)
            }
        }
        return "Active Subscription"
    }

    public var body: some View {
        ZStack {
            // Deep Navy / Midnight Blue Background
            Color(red: 0.035, green: 0.06, blue: 0.11)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 30)

                // ==========================================
                // 1. BRAND HEADER (Authentic Yestream Pro)
                // ==========================================
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
                           let uiImage = UIImage(contentsOfFile: path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 52, height: 52)
                        } else {
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 42))
                                .foregroundColor(Color(red: 0.3, green: 0.65, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("YESTREAM")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .tracking(2.0)
                                .foregroundColor(.white)
                            Text("PRO IPTV PLAYER")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(3.0)
                                .foregroundColor(Color(red: 0.3, green: 0.65, blue: 1.0))
                        }
                    }

                    // Active playlist info
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Active Playlist :")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                        Text(activePlaylist?.name.cleanedIptvTitle ?? "Default Playlist")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        if let type = activePlaylist?.type {
                            Text(type == .xtream ? "XTREAM" : "M3U")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.top, 4)

                    // Real Status & Subscription Info Pill
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(red: 0.188, green: 0.820, blue: 0.345))
                                .frame(width: 7, height: 7)
                            Text(planStatusText)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.caption2)

                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                            Text(expirationString)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.top, 4)
                }

                Spacer()

                // ==========================================
                // 2. MAIN 4 CARDS: Live TV, Movies, Series, EPG Guide
                // ==========================================
                HStack(spacing: 28) {
                    YestreamHeroCard(
                        title: "Live TV",
                        subtitle: "\(appState.channels.count) Channels",
                        systemIcon: "tv",
                        action: {
                            appState.selectedTab = 1
                        }
                    )

                    YestreamHeroCard(
                        title: "Movies",
                        subtitle: "\(appState.vodMovies.count) Films",
                        systemIcon: "film",
                        action: {
                            appState.selectedTab = 2
                        }
                    )

                    YestreamHeroCard(
                        title: "Series",
                        subtitle: "\(appState.seriesList.count) Series",
                        systemIcon: "play.tv",
                        action: {
                            appState.selectedTab = 3
                        }
                    )

                    YestreamHeroCard(
                        title: "EPG Guide",
                        subtitle: "TV Timeline",
                        systemIcon: "calendar.badge.clock",
                        action: {
                            appState.selectedTab = 4
                        }
                    )
                }
                .padding(.horizontal, 48)

                Spacer()

                // ==========================================
                // 3. BOTTOM UTILITY BUTTONS (Fixed frame, no balloon distortion)
                // ==========================================
                HStack(spacing: 32) {
                    Button(action: {
                        Task {
                            await cloud.syncDevice()
                            await appState.loadActivePlaylistCatalog(forceRefresh: true)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("Refresh")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(width: 160, height: 44)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        appState.selectedTab = 5
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14, weight: .bold))
                            Text("Playlists")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(width: 160, height: 44)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        appState.selectedTab = 8
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .bold))
                            Text("Settings")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(width: 160, height: 44)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer().frame(height: 28)

                // ==========================================
                // 4. FOOTER: Real Hardware MAC & Brand Mark
                // ==========================================
                VStack(spacing: 4) {
                    Text("MAC ADDRESS : \(macAddress)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))

                    Text("Yestream Pro • Ultra High Definition Streaming")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 22)
            }
        }
    }
}

// MARK: - Yestream Hero Card Component
struct YestreamHeroCard: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: systemIcon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundColor(.white)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()
            }
            .frame(width: 260, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.13, blue: 0.22).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
            )
        }
        .buttonStyle(.card)
    }
}
