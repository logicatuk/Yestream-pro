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

public struct TvDeviceData: Codable {
    public let id: String?
    public let deviceId: String?
    public let mac: String?
    public let key6: String?
    public let deviceKey: String?
    public let status: String?
    public let plan: String?
    public let expiresAt: String?
    public let portalLoginUrl: String?
}

public struct TvEntitlementData: Codable {
    public let status: String?
    public let plan: String?
    public let expiresAt: String?
    public let accessAllowed: Bool?
    public let remainingDays: Int?
    public let offlineLeaseSignature: String?
}

public struct TvBrandingData: Codable {
    public let brandName: String?
    public let primaryColor: String?
    public let contactEmail: String?
}

public struct TvSyncResponse: Codable {
    public let serverTime: String?
    public let status: String?
    public let plan: String?
    public let expiresAt: String?
    public let accessAllowed: Bool?
    public let remainingDays: Int?
    public let portalLoginUrl: String?
    public let activateUrl: String?
    public let device: TvDeviceData?
    public let entitlement: TvEntitlementData?
    public let playlists: [TvCloudPlaylist]?
    public let branding: TvBrandingData?
}

public struct TvDeviceRegistration: Codable {
    public var deviceId: String?
    public var mac: String
    public var key6: String
    public var deviceKey: String
    public var credential: String?
    public var fingerprint: String?
    public var status: String? // "trial" | "active" | "expired" | "suspended"
    public var plan: String?
    public var expiresAt: String?
    public var serverTime: String?
    public var portalLoginUrl: String?
    public var playlists: [TvCloudPlaylist]?

    public var isExpired: Bool {
        let st = status ?? "trial"
        let pl = plan ?? "TRIAL"
        if st == "expired" || st == "suspended" { return true }
        if pl == "FOREVER" || pl == "LIFETIME" { return false }
        if let exp = expiresAt, let expDate = ISO8601DateFormatter().date(from: exp) {
            return expDate <= Date()
        }
        return false
    }

    /// Generates a deterministic, standard-compliant IEEE 802 MAC address and fingerprint for Apple TV
    public static func getHardwareIdentity(forceNew: Bool = false) -> (mac: String, fingerprint: String) {
        let rawId: String
        if !forceNew, let stored = UserDefaults.standard.string(forKey: "yestream_raw_hardware_id"), !stored.isEmpty {
            rawId = stored
        } else {
            let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let randomSalt = UUID().uuidString.prefix(8)
            let model = UIDevice.current.model
            let sysVer = UIDevice.current.systemVersion
            rawId = "appletv-\(idfv)-\(model)-\(sysVer)-\(randomSalt)"
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
