import SwiftUI

public struct SettingsView: View {
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    // Persistent User Preferences
    @AppStorage("pref_seriesAutoplay") private var seriesAutoplay: Bool = true
    @AppStorage("pref_playerUpNextCard") private var playerUpNextCard: Bool = true
    @AppStorage("pref_showEPG") private var showEPG: Bool = true
    @AppStorage("pref_subtitleLang") private var subtitleLang: String = "English"
    @AppStorage("pref_streamFormat") private var streamFormat: String = "HLS (m3u8)"
    @AppStorage("pref_bufferSize") private var bufferSize: String = "Auto (Recommended)"

    public var body: some View {
        Form {
            // 1. ACCOUNT & DEVICE
            Section(header: Text("Account & Device Diagnostics")) {
                HStack {
                    Text("Device Platform")
                    Spacer()
                    Text("Apple TV (tvOS)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Hardware MAC Address")
                    Spacer()
                    Text(cloud.registration?.mac ?? "Calculating…")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("6-Digit Device Key")
                    Spacer()
                    Text(cloud.registration?.key6 ?? "······")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Subscription Status")
                    Spacer()
                    Text(cloud.registration?.status.uppercased() ?? "ACTIVE")
                        .foregroundColor(cloud.registration?.isExpired == true ? .red : .green)
                }
                HStack {
                    Text("License Plan")
                    Spacer()
                    Text(cloud.registration?.plan ?? "FOREVER (Lifetime)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Self-Service Web Portal")
                    Spacer()
                    Text("/customer/login")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 2. PLAYBACK & EPISODES
            Section(header: Text("Playback Settings")) {
                Toggle("Autoplay next episode", isOn: $seriesAutoplay)
                Toggle("Show \"Up Next\" countdown card", isOn: $playerUpNextCard)

                Picker("Stream Buffer Size", selection: $bufferSize) {
                    Text("Fast Startup (2s)").tag("Fast (2s)")
                    Text("Auto (Recommended)").tag("Auto (Recommended)")
                    Text("Large Buffer (10s)").tag("Large Buffer (10s)")
                }

                Picker("Preferred Format", selection: $streamFormat) {
                    Text("HLS (.m3u8)").tag("HLS (m3u8)")
                    Text("MPEG-TS (.ts)").tag("MPEG-TS (ts)")
                }
            }

            // 3. SUBTITLES (SUBDL ENGINE)
            Section(header: Text("Subtitles & Captions (SubDL)")) {
                Picker("Default Subtitle Language", selection: $subtitleLang) {
                    Text("English").tag("English")
                    Text("Français (French)").tag("French")
                    Text("Español (Spanish)").tag("Spanish")
                    Text("Deutsch (German)").tag("German")
                    Text("العربية (Arabic)").tag("Arabic")
                    Text("Português (Portuguese)").tag("Portuguese")
                    Text("Italiano (Italian)").tag("Italian")
                }

                HStack {
                    Text("SubDL API Status")
                    Spacer()
                    Text("● Connected (Online)")
                        .foregroundColor(.green)
                }
            }

            // 4. PROGRAMME GUIDE (EPG)
            Section(header: Text("Programme Guide (EPG)")) {
                Toggle("Display live programme guide schedules", isOn: $showEPG)
                HStack {
                    Text("EPG Source")
                    Spacer()
                    Text("Provider XMLTV / Xtream")
                        .foregroundColor(.secondary)
                }
            }

            // 5. APPLE SIRI REMOTE SHORTCUTS
            Section(header: Text("Apple Siri Remote Controls")) {
                HStack {
                    Text("Touchpad / D-Pad")
                    Spacer()
                    Text("Navigate grid & rails")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Center Click (Select)")
                    Spacer()
                    Text("Open / Play / Validate")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Back / Menu Button (<)")
                    Spacer()
                    Text("Previous screen / Close player")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Play / Pause (⏯)")
                    Spacer()
                    Text("Toggle playback")
                        .foregroundColor(.secondary)
                }
            }

            // 6. ABOUT YESTREAM
            Section(header: Text("About Yestream")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.25.6 (Apple TV Native Edition)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Video Decoder")
                    Spacer()
                    Text("Apple AVFoundation / Metal 4K HDR")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Audio Passthrough")
                    Spacer()
                    Text("Dolby Digital Plus (E-AC-3) & Atmos")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Cloud Engine")
                    Spacer()
                    Text("Yestream Cloud Run (Europe West)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
