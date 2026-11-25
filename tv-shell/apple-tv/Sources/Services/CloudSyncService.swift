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
                            let type: PlaylistType = cp.type.lowercased() == "m3u" ? .m3u : .xtream
                            let p = Playlist(
                                id: cp.id,
                                name: cp.name.isEmpty ? "Cloud Playlist" : cp.name,
                                type: type,
                                url: cp.url ?? cp.host ?? "",
                                username: cp.username,
                                password: cp.password
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
}
