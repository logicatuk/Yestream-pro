import Foundation
import CryptoKit
import UIKit

public struct TvCloudPlaylist: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: String // "m3u" | "xtream" | "stalker"
    public let url: String?
    public let host: String?
    public let username: String?
    public let password: String?
}

public struct TvDeviceRegistration: Codable {
    public let deviceId: String?
    public let mac: String
    public let key6: String
    public let deviceKey: String
    public let status: String // "trial" | "active" | "expired" | "suspended"
    public let plan: String
    public let expiresAt: String
    public let serverTime: String?
    public let portalLoginUrl: String?
    public let playlists: [TvCloudPlaylist]?

    public var isExpired: Bool {
        if status == "expired" || status == "suspended" { return true }
        if plan == "FOREVER" || plan == "LIFETIME" { return false }
        if let expDate = ISO8601DateFormatter().date(from: expiresAt) {
            return expDate <= Date()
        }
        return false
    }

    /// Generates a deterministic, standard-compliant IEEE 802 MAC address and fingerprint for Apple TV
    public static func getHardwareIdentity() -> (mac: String, fingerprint: String) {
        let rawId: String
        if let stored = UserDefaults.standard.string(forKey: "yestream_raw_hardware_id"), !stored.isEmpty {
            rawId = stored
        } else {
            let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let model = UIDevice.current.model
            let sysVer = UIDevice.current.systemVersion
            rawId = "appletv-\(idfv)-\(model)-\(sysVer)"
            UserDefaults.standard.set(rawId, forKey: "yestream_raw_hardware_id")
        }

        let macHash = SHA256.hash(data: Data("yestream-pro-mac:\(rawId)".utf8))
        let fpHash = SHA256.hash(data: Data("yestream-pro-fp:\(rawId)".utf8))

        var macBytes = Array(macHash.prefix(6))
        // Set locally administered unicast bit (02:xx:xx:xx:xx:xx)
        macBytes[0] = (macBytes[0] & 0xfe) | 0x02

        let macString = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
        let fpString = fpHash.map { String(format: "%02x", $0) }.joined()

        return (macString, fpString)
    }
}
