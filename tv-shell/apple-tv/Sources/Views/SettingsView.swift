import SwiftUI

public struct SettingsView: View {
    @ObservedObject var cloud = CloudSyncService.shared

    public var body: some View {
        Form {
            Section(header: Text("Account & Device Diagnostics")) {
                HStack {
                    Text("Device Platform")
                    Spacer()
                    Text("Apple TV (tvOS)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Hardware MAC")
                    Spacer()
                    Text(cloud.registration?.mac ?? "Calculating…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("Device Key")
                    Spacer()
                    Text(cloud.registration?.key6 ?? "······")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                }
                HStack {
                    Text("License Status")
                    Spacer()
                    Text(cloud.registration?.status.uppercased() ?? "TRIAL")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Subscription Plan")
                    Spacer()
                    Text(cloud.registration?.plan ?? "Standard")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("About Yestream")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.25.6 (Apple TV Edition)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Video Engine")
                    Spacer()
                    Text("Apple AVFoundation / Metal")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Online Subtitles")
                    Spacer()
                    Text("SubDL API Connected")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
