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

    // Buffer & Hardware Optimization
    @AppStorage("pref_bufferDurationSeconds") private var bufferDurationSeconds: Double = 3.0
    @AppStorage("pref_forwardBufferSizeMB") private var forwardBufferSizeMB: Int = 128
    @AppStorage("pref_autoReconnect") private var autoReconnect: Bool = true

    // Decoder Preferences
    @AppStorage("pref_videoDecoder") private var videoDecoder: String = "Apple VideoToolbox (Metal 4K HDR)"
    @AppStorage("pref_matchFrameRate") private var matchFrameRate: Bool = true
    @AppStorage("pref_deinterlacing") private var deinterlacing: String = "Auto (Hardware Blend)"
    @AppStorage("pref_audioPassthrough") private var audioPassthrough: String = "Auto (Dolby Atmos & 5.1)"

    // Sleep Timer
    @AppStorage("pref_sleepTimerSetting") private var sleepTimerSetting: Int = 0
    @AppStorage("pref_preventSleepDuringPlayback") private var preventSleepDuringPlayback: Bool = true

    @State private var showExpiredPreview: Bool = false

    public var body: some View {
        Form {
            // ==========================================
            // 1. ACCOUNT, LICENSE & CLOUD SYNC
            // ==========================================
            Section(header: Text("Account & Cloud Sync")) {
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
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cloud.registration?.isExpired == true ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(cloud.registration?.status?.uppercased() ?? "ACTIVE")
                            .fontWeight(.bold)
                            .foregroundColor(cloud.registration?.isExpired == true ? .red : .green)
                    }
                }
                HStack {
                    Text("License Plan")
                    Spacer()
                    Text(cloud.registration?.plan ?? "YEAR_1")
                        .foregroundColor(.secondary)
                }
                if let exp = cloud.registration?.expiresAt, !exp.isEmpty {
                    HStack {
                        Text("Expires On")
                        Spacer()
                        Text(String(exp.prefix(10)))
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    Task {
                        await cloud.syncDevice()
                    }
                }) {
                    HStack {
                        Image(systemName: cloud.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        Text(cloud.isSyncing ? "Syncing from Cloud…" : "Force Cloud Sync Now")
                            .fontWeight(.semibold)
                    }
                }

                if !cloud.syncMessage.isEmpty {
                    Text(cloud.syncMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Button(action: {
                    showExpiredPreview = true
                }) {
                    HStack {
                        Image(systemName: "hourglass.badge.plus")
                        Text("Preview Expired & Activation Screen")
                    }
                }
            }

            // ==========================================
            // 2. BUFFER DURATION & NETWORK OPTIMIZATION
            // ==========================================
            Section(header: Text("Buffer Duration & Network Optimization")) {
                Picker("Stream Buffer Duration", selection: $bufferDurationSeconds) {
                    Text("Ultra-Low Latency (1.0s) - Live Sports").tag(1.0)
                    Text("Fast Startup (3.0s) - Recommended").tag(3.0)
                    Text("Stable Buffer (6.0s) - Standard Wi-Fi").tag(6.0)
                    Text("Deep Buffer (12.0s) - Poor Wi-Fi / 4K UHD").tag(12.0)
                }

                Picker("Forward Memory Cache", selection: $forwardBufferSizeMB) {
                    Text("Conservative (64 MB)").tag(64)
                    Text("Balanced (128 MB) - Default").tag(128)
                    Text("High Capacity (256 MB)").tag(256)
                }

                Toggle("Auto-reconnect on dropped stream", isOn: $autoReconnect)

                Picker("Preferred Stream Format", selection: $streamFormat) {
                    Text("HLS (.m3u8)").tag("HLS (m3u8)")
                    Text("MPEG-TS (.ts)").tag("MPEG-TS (ts)")
                }
            }

            // ==========================================
            // 3. HARDWARE VIDEO & AUDIO DECODER
            // ==========================================
            Section(header: Text("Hardware Video & Audio Decoder")) {
                Picker("Video Decoding Engine", selection: $videoDecoder) {
                    Text("Apple VideoToolbox (Metal 4K HDR)").tag("Apple VideoToolbox (Metal 4K HDR)")
                    Text("Apple AVFoundation Standard").tag("Apple AVFoundation Standard")
                    Text("Software Codec Fallback").tag("Software Codec Fallback")
                }

                Toggle("Match Content Dynamic Range & Frame Rate (24p/50p/60p)", isOn: $matchFrameRate)

                Picker("Deinterlacing Mode", selection: $deinterlacing) {
                    Text("Auto (Hardware Blend)").tag("Auto (Hardware Blend)")
                    Text("Bob / Double Rate (50/60 fps)").tag("Bob / Double Rate (50/60 fps)")
                    Text("Disabled").tag("Disabled")
                }

                Picker("Audio Passthrough & Output", selection: $audioPassthrough) {
                    Text("Auto (Dolby Atmos & 5.1 Surround)").tag("Auto (Dolby Atmos & 5.1)")
                    Text("Stereo Downmix (PCM)").tag("Stereo Downmix (PCM)")
                }
            }

            // ==========================================
            // 4. SLEEP TIMER & STANDBY
            // ==========================================
            Section(header: Text("Sleep Timer & Auto-Standby")) {
                Picker("Sleep Timer", selection: $sleepTimerSetting) {
                    Text("Off").tag(0)
                    Text("15 Minutes").tag(15)
                    Text("30 Minutes").tag(30)
                    Text("45 Minutes").tag(45)
                    Text("60 Minutes (1 Hour)").tag(60)
                    Text("90 Minutes (1.5 Hours)").tag(90)
                    Text("120 Minutes (2 Hours)").tag(120)
                }
                .onChange(of: sleepTimerSetting) { newVal in
                    appState.setSleepTimer(minutes: newVal)
                }

                if appState.sleepTimerMinutes > 0, let endsAt = appState.sleepTimerEndsAt {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.indigo)
                        Text("Sleep Timer Active")
                            .fontWeight(.bold)
                        Spacer()
                        Text("Turns off at \(endsAt, style: .time)")
                            .foregroundColor(.secondary)
                    }

                    Button("Cancel Sleep Timer") {
                        sleepTimerSetting = 0
                        appState.cancelSleepTimer()
                    }
                    .foregroundColor(.red)
                }

                Toggle("Prevent screen saver during video playback", isOn: $preventSleepDuringPlayback)
            }

            // ==========================================
            // 5. PLAYBACK & EPISODES
            // ==========================================
            Section(header: Text("Playback & Guide")) {
                Toggle("Autoplay next episode", isOn: $seriesAutoplay)
                Toggle("Show \"Up Next\" countdown card", isOn: $playerUpNextCard)
                Toggle("Display live programme guide schedules (EPG)", isOn: $showEPG)

                Picker("Default Subtitle Language (SubDL)", selection: $subtitleLang) {
                    Text("English").tag("English")
                    Text("Français (French)").tag("French")
                    Text("Español (Spanish)").tag("Spanish")
                    Text("Deutsch (German)").tag("German")
                    Text("العربية (Arabic)").tag("Arabic")
                    Text("Português (Portuguese)").tag("Portuguese")
                    Text("Italiano (Italian)").tag("Italian")
                }
            }

            // ==========================================
            // 6. ABOUT YESTREAM
            // ==========================================
            Section(header: Text("About Yestream")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.25.6 (Apple TV Native)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Cloud Engine")
                    Spacer()
                    Text("Yestream Cloud Run (Europe West)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("SubDL Subtitles")
                    Spacer()
                    Text("● Connected (Online)")
                        .foregroundColor(.green)
                }
            }
        }
        .fullScreenCover(isPresented: $showExpiredPreview) {
            DeviceExpiredView()
        }
    }
}
