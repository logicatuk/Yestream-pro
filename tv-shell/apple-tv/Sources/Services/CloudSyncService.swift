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
    }

    private func loadStored() {
        if let data = UserDefaults.standard.data(forKey: "yestream_apple_tv_registration"),
           let reg = try? JSONDecoder().decode(TvDeviceRegistration.self, from: data) {
            self.registration = reg
        }
    }

    private func saveRegistration(_ reg: TvDeviceRegistration) {
        self.registration = reg
        if let data = try? JSONEncoder().encode(reg) {
            UserDefaults.standard.set(data, forKey: "yestream_apple_tv_registration")
        }
    }

    public func registerDevice() async {
        let (mac, fp) = TvDeviceRegistration.getHardwareIdentity()
        guard let url = URL(string: "\(Self.endpoint)/api/v1/devices/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "mac": mac,
            "fingerprint": fp,
            "platform": "Apple TV",
            "model": "Apple TV 4K",
            "os": "tvOS"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                let reg = try JSONDecoder().decode(TvDeviceRegistration.self, from: data)
                self.saveRegistration(reg)
                // Trigger auto-sync once registered
                await self.syncDevice()
            }
        } catch {
            print("Apple TV Cloud Register Error: \(error)")
        }
    }

    public func syncDevice() async {
        guard let reg = registration else {
            await registerDevice()
            return
        }

        self.isSyncing = true
        self.syncMessage = "Syncing with Yestream Cloud…"

        guard let url = URL(string: "\(Self.endpoint)/api/v1/device/sync") else {
            self.isSyncing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "mac": reg.mac,
            "deviceKey": reg.deviceKey,
            "fingerprint": TvDeviceRegistration.getHardwareIdentity().fingerprint
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                let updated = try JSONDecoder().decode(TvDeviceRegistration.self, from: data)
                self.saveRegistration(updated)
                self.syncMessage = "Synchronized!"
            }
        } catch {
            self.syncMessage = "Sync failed. Check internet connection."
        }

        self.isSyncing = false
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        self.syncMessage = ""
    }
}
