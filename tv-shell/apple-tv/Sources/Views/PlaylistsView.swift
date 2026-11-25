import SwiftUI

public struct PlaylistsView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    @State private var showAddModal = false
    @State private var showEditModal = false
    @State private var editingPlaylistId: String?
    @State private var playlistType: PlaylistType = .xtream
    @State private var playlistName = ""
    @State private var serverUrl = ""
    @State private var username = ""
    @State private var password = ""

    public var body: some View {
        HStack(alignment: .top, spacing: 44) {
            // LEFT PANE: Quick Connect QR Card
            VStack(alignment: .leading, spacing: 22) {
                // Header with brand logo & status
                HStack(alignment: .center) {
                    HStack(spacing: 12) {
                        if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
                           let uiImage = UIImage(contentsOfFile: path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("YESTREAM")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .tracking(1.5)
                            Text("QUICK CONNECT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    if let reg = cloud.registration {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(reg.isExpired ? Color.red : Color.green)
                                .frame(width: 8, height: 8)
                            Text((reg.status ?? "trial").uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(reg.isExpired ? .red : .green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                    }
                }

                let portalUrl = cloud.registration?.portalLoginUrl ??
                    "https://yestream.ai.studio/customer/login?mac=\(cloud.registration?.mac ?? "")&key=\(cloud.registration?.key6 ?? "")"

                // QR Code Centered Box
                VStack(spacing: 12) {
                    QRCodeView(urlString: portalUrl)
                        .frame(width: 210, height: 210)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

                    Text("Scan to connect your playlists from iPhone, iPad, or Mac without typing on Apple TV.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                // Device Credentials
                VStack(spacing: 10) {
                    HStack {
                        Text("MAC ADDRESS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cloud.registration?.mac ?? "Calculating…")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Divider().background(Color.white.opacity(0.12))
                    HStack {
                        Text("DEVICE KEY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cloud.registration?.key6 ?? "······")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)

                // Sync Button
                Button(action: {
                    Task {
                        await cloud.syncDevice()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: cloud.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        Text(cloud.isSyncing ? "Syncing Cloud…" : "Sync Cloud Playlists")
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                if !cloud.syncMessage.isEmpty {
                    Text(cloud.syncMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer()
            }
            .frame(width: 480)
            .padding(24)
            .background(Color.black.opacity(0.35))
            .cornerRadius(20)
            .focusSection()

            // RIGHT PANE: Playlists List
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Playlists")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configured IPTV streaming sources on this Apple TV")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showAddModal = true
                    }) {
                        Label("Add Playlist", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if appState.playlists.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.7))

                        VStack(spacing: 8) {
                            Text("No Playlists Added Yet")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Scan the Quick Connect QR code on the left to add a playlist from your phone, or add an Xtream source manually.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 460)
                        }

                        HStack(spacing: 20) {
                            Button(action: {
                                showAddModal = true
                            }) {
                                Label("Add Manually", systemImage: "plus.circle")
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                Task {
                                    await cloud.syncDevice()
                                }
                            }) {
                                Label("Sync from Cloud", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(appState.playlists) { p in
                        HStack(spacing: 16) {
                            Image(systemName: p.id == appState.activePlaylistId ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(p.id == appState.activePlaylistId ? .green : .secondary)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if p.id == appState.activePlaylistId {
                                        Text("CONNECTED")
                                            .font(.caption2)
                                            .fontWeight(.heavy)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
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
                                    .lineLimit(1)
                            }
                            Spacer()

                            HStack(spacing: 12) {
                                if p.id != appState.activePlaylistId {
                                    Button("Connect") {
                                        appState.selectActivePlaylist(id: p.id, forceRefresh: false)
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button(action: {
                                        appState.selectActivePlaylist(id: p.id, forceRefresh: true)
                                    }) {
                                        Label("Re-sync", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Button(action: {
                                    editingPlaylistId = p.id
                                    playlistName = p.name
                                    let (u, pass) = XtreamService.extractCredentials(from: p.url, user: p.username, pass: p.password)
                                    username = u
                                    password = pass

                                    if !u.isEmpty || p.type == .xtream {
                                        playlistType = .xtream
                                        serverUrl = XtreamService.normalizeServerUrl(p.url)
                                    } else {
                                        playlistType = .m3u
                                        serverUrl = p.url
                                    }
                                    showEditModal = true
                                }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.bordered)

                                Button(action: {
                                    appState.deletePlaylist(id: p.id)
                                } ) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding()
            .focusSection()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .sheet(isPresented: $showEditModal) {
            VStack(spacing: 20) {
                Text("Edit Playlist")
                    .font(.title2)
                    .fontWeight(.bold)

                Picker("Playlist Type", selection: $playlistType) {
                    Text("Xtream Codes API").tag(PlaylistType.xtream)
                    Text("M3U Playlist").tag(PlaylistType.m3u)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 6)

                TextField("Playlist Name", text: $playlistName)

                if playlistType == .xtream {
                    TextField("Server URL (http://example.com:80)", text: $serverUrl)
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                } else {
                    TextField("M3U Playlist URL (http://.../playlist.m3u8)", text: $serverUrl)
                }

                HStack(spacing: 20) {
                    Button("Cancel") {
                        showEditModal = false
                    }
                    Button("Save Changes") {
                        if let id = editingPlaylistId {
                            let (u, pass) = XtreamService.extractCredentials(from: serverUrl, user: username, pass: password)
                            let finalUser = playlistType == .xtream ? (username.isEmpty ? u : username) : nil
                            let finalPass = playlistType == .xtream ? (password.isEmpty ? pass : password) : nil
                            let cleanUrl = (playlistType == .xtream) ? XtreamService.normalizeServerUrl(serverUrl) : serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)

                            let updated = Playlist(
                                id: id,
                                name: playlistName.isEmpty ? (playlistType == .xtream ? "Xtream Service" : "M3U Playlist") : playlistName,
                                type: playlistType,
                                url: cleanUrl,
                                username: finalUser,
                                password: finalPass
                            )
                            appState.updatePlaylist(updated)
                        }
                        showEditModal = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(40)
            .frame(width: 600)
        }
        .sheet(isPresented: $showAddModal) {
            VStack(spacing: 20) {
                Text("Add Playlist")
                    .font(.title2)
                    .fontWeight(.bold)

                Picker("Playlist Type", selection: $playlistType) {
                    Text("Xtream Codes API").tag(PlaylistType.xtream)
                    Text("M3U Playlist").tag(PlaylistType.m3u)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 6)

                TextField("Playlist Name", text: $playlistName)

                if playlistType == .xtream {
                    TextField("Server URL (http://example.com:80)", text: $serverUrl)
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                } else {
                    TextField("M3U Playlist URL (http://.../playlist.m3u8)", text: $serverUrl)
                }

                HStack {
                    Button("Cancel") {
                        showAddModal = false
                    }
                    Button("Save Playlist") {
                        let (u, pass) = XtreamService.extractCredentials(from: serverUrl, user: username, pass: password)
                        let finalUser = playlistType == .xtream ? (username.isEmpty ? u : username) : nil
                        let finalPass = playlistType == .xtream ? (password.isEmpty ? pass : password) : nil
                        let cleanUrl = (playlistType == .xtream) ? XtreamService.normalizeServerUrl(serverUrl) : serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)

                        let p = Playlist(
                            name: playlistName.isEmpty ? (playlistType == .xtream ? "Xtream Service" : "M3U Playlist") : playlistName,
                            type: playlistType,
                            url: cleanUrl,
                            username: finalUser,
                            password: finalPass
                        )
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
