import SwiftUI

public struct PlaylistsView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    @State private var showAddModal = false
    @State private var playlistName = ""
    @State private var serverUrl = ""
    @State private var username = ""
    @State private var password = ""

    public var body: some View {
        HStack(spacing: 40) {
            // LEFT PANE: Quick Connect QR Card
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("QUICK CONNECT")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(6)

                    Spacer()

                    if let reg = cloud.registration {
                        Text("● \(reg.status.uppercased()) (\(reg.plan))")
                            .font(.caption2)
                            .foregroundColor(reg.isExpired ? .red : .green)
                    }
                }

                let portalUrl = cloud.registration?.portalLoginUrl ??
                    "https://yestream.ai.studio/customer/login?mac=\(cloud.registration?.mac ?? "")&key=\(cloud.registration?.key6 ?? "")"

                HStack {
                    Spacer()
                    QRCodeView(urlString: portalUrl)
                        .frame(width: 220, height: 220)
                        .background(Color.white)
                        .cornerRadius(12)
                    Spacer()
                }

                Text("Scan to connect your playlists from your iPhone, iPad, or computer without typing with your Apple TV remote.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("MAC ADDRESS").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(cloud.registration?.mac ?? "Calculating…")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("DEVICE KEY").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(cloud.registration?.key6 ?? "······")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)

                Button(action: {
                    Task {
                        await cloud.syncDevice()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(cloud.isSyncing ? "Syncing Cloud…" : "↻ Sync Cloud Playlists")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !cloud.syncMessage.isEmpty {
                    Text(cloud.syncMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .frame(width: 440)
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)

            // RIGHT PANE: Playlists List
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Playlists")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configured IPTV streaming sources on this Apple TV")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("+ Add Playlist") {
                        showAddModal = true
                    }
                    .buttonStyle(.bordered)
                }

                if appState.playlists.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No playlists connected yet.")
                            .font(.headline)
                        Text("Scan the QR code on the left to add a playlist from your phone, or click '+ Add Playlist' above.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(appState.playlists) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if p.id == appState.activePlaylistId {
                                        Text("● ACTIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                    Text(p.name)
                                        .font(.headline)
                                    Text(p.type.rawValue.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                Text(p.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if p.id != appState.activePlaylistId {
                                Button("Select") {
                                    appState.activePlaylistId = p.id
                                    appState.savePlaylists()
                                    Task {
                                        await appState.loadChannelsForActivePlaylist()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showAddModal) {
            VStack(spacing: 20) {
                Text("Add Xtream Playlist")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Playlist Name", text: $playlistName)
                TextField("Server URL (http://example.com:80)", text: $serverUrl)
                TextField("Username", text: $username)
                SecureField("Password", text: $password)

                HStack {
                    Button("Cancel") {
                        showAddModal = false
                    }
                    Button("Save Playlist") {
                        let p = Playlist(name: playlistName.isEmpty ? "Xtream Service" : playlistName, type: .xtream, url: serverUrl, username: username, password: password)
                        appState.addPlaylist(p)
                        showAddModal = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(40)
            .frame(width: 600)
        }
    }
}
