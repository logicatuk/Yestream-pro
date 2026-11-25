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

    private var expirationString: String {
        if let exp = cloud.registration?.expiresAt {
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: exp) {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yyyy HH:mm"
                return df.string(from: date)
            }
        }
        return "14/12/2027 17:59"
    }

    public var body: some View {
        ZStack {
            // Deep Navy Blue Background (Hot IPTV / IBO Ice UI: #08101E)
            Color(red: 0.035, green: 0.065, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                // ==========================================
                // 1. BRAND HEADER (Hot IPTV / IBO Player Style)
                // ==========================================
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 38))
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.15))

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Xtream Code")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Hot IPTV")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }

                    // Current list label
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.2))
                        Text("Current list :")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Text(activePlaylist?.name.cleanedIptvTitle ?? "List 1")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.25))
                    }
                    .padding(.top, 4)

                    // Active & Expiration Status Pill
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("😊")
                            Text("Active")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 6) {
                            Text("⏳")
                            Text("Expires on \(expirationString)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.top, 4)
                }

                Spacer()

                // ==========================================
                // 2. MAIN 3 CARDS: Live TV, Movies, Series
                // ==========================================
                HStack(spacing: 36) {
                    HotIptvCard(
                        title: "Live TV",
                        systemIcon: "tv",
                        action: {
                            appState.selectedTab = 1
                        }
                    )

                    HotIptvCard(
                        title: "Movies",
                        systemIcon: "film",
                        action: {
                            appState.selectedTab = 2
                        }
                    )

                    HotIptvCard(
                        title: "Series",
                        systemIcon: "play.tv",
                        action: {
                            appState.selectedTab = 3
                        }
                    )
                }
                .padding(.horizontal, 80)

                Spacer()

                // ==========================================
                // 3. BOTTOM UTILITY PILL BUTTONS
                // ==========================================
                HStack(spacing: 24) {
                    Button(action: {
                        Task {
                            await cloud.syncDevice()
                            await appState.loadActivePlaylistCatalog(forceRefresh: true)
                        }
                    }) {
                        Text("Refresh")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        appState.selectedTab = 4
                    }) {
                        Text("Change Playlist")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        appState.selectedTab = 6
                    }) {
                        Text("Settings")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 32)

                // ==========================================
                // 4. FOOTER: MAC & DISCLAIMER
                // ==========================================
                VStack(spacing: 4) {
                    Text("Your MAC : \(macAddress)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Text("HotIPTV.app © is just a media player, No channels included")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.9, green: 0.45, blue: 0.2))
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Hot IPTV Card Component
struct HotIptvCard: View {
    let title: String
    let systemIcon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: systemIcon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundColor(.white)

                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .frame(width: 280, height: 230)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.13, blue: 0.22).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(.card)
    }
}
