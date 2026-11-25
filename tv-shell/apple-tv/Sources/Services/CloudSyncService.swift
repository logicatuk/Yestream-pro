import Foundation

@MainActor
public class CloudSyncService: ObservableObject {
    public static let shared = CloudSyncService()
    public static let endpoint = "https://yestream-405211835468.europe-west2.run.app"

    @Published public var registration: TvDeviceRegistration?
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String = ""

    private let session = URLSession(configuration: .default)

    public init() {
        loadStored()
        if registration == nil {
            let (mac, fp) = TvDeviceRegistration.getHardwareIdentity()
            self.registration = TvDeviceRegistration(
                deviceId: nil,
                mac: mac,
                key6: "······",
                deviceKey: "······",
                credential: nil,
                fingerprint: fp,
                status: "trial",
                plan: "TRIAL",
                expiresAt: "",
                serverTime: nil,
                portalLoginUrl: nil,
                playlists: nil
            )
        }
    }

    private func loadStored() {
        if let data = UserDefaults.standard.data(forKey: "yestream_apple_tv_registration"),
           let reg = try? JSONDecoder().decode(TvDeviceRegistration.self, from: data) {
            self.registration = reg
        }
    }

    public func saveRegistration(_ reg: TvDeviceRegistration) {
        self.registration = reg
        if let data = try? JSONEncoder().encode(reg) {
            UserDefaults.standard.set(data, forKey: "yestream_apple_tv_registration")
        }
    }

    public func registerDevice(forceNew: Bool = false) async {
        let (mac, fp) = TvDeviceRegistration.getHardwareIdentity(forceNew: forceNew)
        guard let url = URL(string: "\(Self.endpoint)/api/v1/devices/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "mac": mac,
            "hardwareFingerprint": fp,
            "fingerprint": fp,
            "platform": "Apple TV",
            "model": "Apple TV 4K",
            "os": "tvOS",
            "appVersion": "v0.4.0"
        ]

        if !forceNew, let cred = registration?.credential, !cred.isEmpty {
            payload["credential"] = cred
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                if (200...299).contains(httpRes.statusCode) {
                    var reg = try JSONDecoder().decode(TvDeviceRegistration.self, from: data)
                    reg.fingerprint = fp
                    self.saveRegistration(reg)
                    print("Apple TV registered successfully: \(reg.mac), credential: \(reg.credential ?? "none")")
                    await self.syncDevice()
                } else if httpRes.statusCode == 409 && !forceNew {
                    print("MAC conflict detected on register. Generating fresh hardware identity...")
                    await self.registerDevice(forceNew: true)
                } else {
                    print("Register failed with status: \(httpRes.statusCode)")
                }
            }
        } catch {
            print("Apple TV Cloud Register Error: \(error)")
        }
    }

    public func syncDevice() async {
        if registration == nil || (registration?.credential ?? "").isEmpty {
            await registerDevice()
        }

        guard var reg = registration, let credential = reg.credential, !credential.isEmpty else {
            self.syncMessage = "Device not registered."
            return
        }

        self.isSyncing = true
        self.syncMessage = "Syncing with Yestream Cloud…"

        guard let url = URL(string: "\(Self.endpoint)/api/v1/device/sync") else {
            self.isSyncing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let devId = reg.deviceId {
            request.setValue(devId, forHTTPHeaderField: "x-device-id")
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                if (200...299).contains(httpRes.statusCode) {
                    let syncResp = try JSONDecoder().decode(TvSyncResponse.self, from: data)

                    // Update live entitlement & access status
                    let newStatus = syncResp.entitlement?.status ?? syncResp.device?.status ?? syncResp.status ?? (reg.status ?? "trial")
                    let newPlan = syncResp.entitlement?.plan ?? syncResp.device?.plan ?? syncResp.plan ?? (reg.plan ?? "TRIAL")
                    let newExpiry = syncResp.entitlement?.expiresAt ?? syncResp.device?.expiresAt ?? syncResp.expiresAt ?? (reg.expiresAt ?? "")

                    reg.status = newStatus
                    reg.plan = newPlan
                    reg.expiresAt = newExpiry
                    if let st = syncResp.serverTime { reg.serverTime = st }
                    if let portal = syncResp.portalLoginUrl ?? syncResp.device?.portalLoginUrl {
                        reg.portalLoginUrl = portal
                    }
                    reg.playlists = syncResp.playlists
                    self.saveRegistration(reg)

                    // Reconcile and activate playlists
                    if let cloudLists = syncResp.playlists, !cloudLists.isEmpty {
                        var localPlaylists: [Playlist] = []
                        for cp in cloudLists {
                            let rawUrl = cp.url ?? cp.host ?? ""
                            let (u, pass) = XtreamService.extractCredentials(from: rawUrl, user: cp.username, pass: cp.password)
                            
                            // If credentials exist (either in URL or fields), treat as Xtream with clean host URL
                            let isXtream = !u.isEmpty || cp.type.lowercased() == "xtream"
                            let cleanUrl = isXtream ? XtreamService.normalizeServerUrl(rawUrl) : rawUrl
                            let type: PlaylistType = isXtream ? .xtream : .m3u

                            let p = Playlist(
                                id: cp.id,
                                name: cp.name.isEmpty ? (isXtream ? "Xtream Service" : "Cloud Playlist") : cp.name,
                                type: type,
                                url: cleanUrl,
                                username: isXtream ? (u.isEmpty ? nil : u) : nil,
                                password: isXtream ? (pass.isEmpty ? nil : pass) : nil
                            )
                            localPlaylists.append(p)
                        }

                        AppState.shared.playlists = localPlaylists
                        if AppState.shared.activePlaylistId == nil || !localPlaylists.contains(where: { $0.id == AppState.shared.activePlaylistId }) {
                            AppState.shared.activePlaylistId = localPlaylists.first?.id
                        }
                        AppState.shared.savePlaylists()

                        Task {
                            await AppState.shared.loadActivePlaylistCatalog(forceRefresh: false)
                        }

                        self.syncMessage = "Synced! \(localPlaylists.count) playlist(s) connected."
                    } else {
                        self.syncMessage = "Synced! Device is \(newStatus.uppercased()). No playlists in cloud."
                    }
                } else if httpRes.statusCode == 401 {
                    print("Bearer credential expired or rejected (401). Re-authenticating...")
                    await self.registerDevice(forceNew: false)
                } else {
                    self.syncMessage = "Sync returned error code: \(httpRes.statusCode)"
                }
            }
        } catch {
            print("Sync Error: \(error)")
            self.syncMessage = "Sync failed. Check internet connection."
        }

        self.isSyncing = false
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        self.syncMessage = ""
    }

    public func deletePlaylistFromCloud(id: String) async {
        guard let reg = registration, let credential = reg.credential, !credential.isEmpty else {
            return
        }
        guard let url = URL(string: "\(Self.endpoint)/api/v1/device/playlists/\(id)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        if let devId = reg.deviceId {
            request.setValue(devId, forHTTPHeaderField: "x-device-id")
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                print("[CloudSync] DELETE playlist \(id) status: \(httpRes.statusCode)")
                if !(200...299).contains(httpRes.statusCode) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? String {
                        print("[CloudSync] DELETE error body: \(err)")
                        self.syncMessage = "Cloud notice: \(err)"
                    } else if let errStr = String(data: data, encoding: .utf8) {
                        print("[CloudSync] DELETE error body: \(errStr)")
                        self.syncMessage = "Cloud delete failed: \(httpRes.statusCode)"
                    }
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    self.syncMessage = ""
                }
            }
        } catch {
            print("[CloudSync] DELETE playlist error: \(error)")
        }
    }

    public func pushPlaylistToCloud(_ playlist: Playlist) async {
        guard let reg = registration, let credential = reg.credential, !credential.isEmpty else {
            return
        }
        guard let url = URL(string: "\(Self.endpoint)/api/v1/device/playlists") else {
            return
        }

        var payload: [String: Any] = [
            "name": playlist.name,
            "type": playlist.type == .xtream ? "xtream" : "m3u"
        ]
        if playlist.id.starts(with: "pl_") {
            payload["id"] = playlist.id
        }
        if playlist.type == .xtream {
            payload["host"] = playlist.url
            payload["username"] = playlist.username ?? ""
            payload["password"] = playlist.password ?? ""
            if let u = playlist.username, let p = playlist.password {
                payload["url"] = "\(playlist.url)/get.php?username=\(u)&password=\(p)&type=m3u_plus"
            }
        } else {
            payload["url"] = playlist.url
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let devId = reg.deviceId {
            request.setValue(devId, forHTTPHeaderField: "x-device-id")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                print("[CloudSync] POST playlist status: \(httpRes.statusCode)")
            }
        } catch {
            print("[CloudSync] Push playlist error: \(error)")
        }
    }
}
