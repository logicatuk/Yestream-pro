import SwiftUI

// MARK: - Device Expired / Activation Gate View
public struct DeviceExpiredView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared
    @State private var isChecking: Bool = false
    @State private var checkResultMessage: String = ""

    public init() {}

    private var registration: TvDeviceRegistration? {
        cloud.registration
    }

    private var activationUrl: String {
        if let custom = registration?.portalLoginUrl, !custom.isEmpty {
            return custom
        }
        let mac = registration?.mac ?? ""
        let key = registration?.deviceKey ?? registration?.key6 ?? ""
        return "https://yestream.app/activate?mac=\(mac)&key=\(key)"
    }

    public var body: some View {
        ZStack {
            // Dark luxury background with subtle amber/red ambient glow
            Color(red: 0.04, green: 0.06, blue: 0.11)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.red.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 80,
                endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                // ==========================================
                // 1. BRAND HEADER: Logo + Title
                // ==========================================
                HStack(spacing: 12) {
                    if cloud.registration?.isExpired == false {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }

                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YESTREAM")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundColor(.white)
                        Text("PRO IPTV PLAYER")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Color.cyan)
                    }

                    if cloud.registration?.isExpired == false {
                        Spacer()
                    }
                }
                .padding(.top, 40)

                // ==========================================
                // 2. EXPIRED BANNER
                // ==========================================
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.2))

                        Text("Your trial period has expired.")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("To continue enjoying Live TV, Movies, Series, and the EPG Timeline, please renew or activate your device.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 800)
                }

                // ==========================================
                // 3. ACTIVATION HERO CARD: QR Code + Manual Details
                // ==========================================
                HStack(spacing: 48) {
                    // QR Code Card
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(width: 210, height: 210)
                                .shadow(color: Color.black.opacity(0.4), radius: 10)

                            QRCodeView(urlString: activationUrl)
                                .frame(width: 186, height: 186)
                        }

                        Text("Scan with phone to activate")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 240)

                    // Device Credentials & Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DEVICE MAC ADDRESS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))

                            Text(registration?.mac ?? "DA:E5:4A:7C:18:3F")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DEVICE ACTIVATION KEY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))

                            Text(registration?.deviceKey ?? registration?.key6 ?? "••••••")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.cyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("PORTAL URL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                            Text("https://yestream.app/activate")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(width: 380, alignment: .leading)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )

                // ==========================================
                // 4. ACTION BUTTONS: Refresh Status & Playlists
                // ==========================================
                HStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await checkStatus()
                        }
                    }) {
                        HStack(spacing: 10) {
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(isChecking ? "Checking..." : "Refresh Status")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(ExpiredActionButtonStyle(isPrimary: true))
                    .disabled(isChecking)

                    Button(action: {
                        appState.selectedTab = 5 // Navigate to Playlists tab
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14))
                            Text("Manage Playlists")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .buttonStyle(ExpiredActionButtonStyle(isPrimary: false))
                }

                if !checkResultMessage.isEmpty {
                    Text(checkResultMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.cyan)
                        .animation(.easeInOut, value: checkResultMessage)
                }

                Spacer()
            }
            .padding(.horizontal, 48)
        }
    }

    private func checkStatus() async {
        isChecking = true
        checkResultMessage = "Checking activation with Yestream Cloud…"
        await cloud.syncDevice()
        isChecking = false

        if cloud.registration?.isExpired == false {
            checkResultMessage = "Device active! Unlocking content…"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            checkResultMessage = ""
        } else {
            checkResultMessage = "Subscription is still expired. Please complete renewal above."
        }
    }
}

// MARK: - Action Button Style
private struct ExpiredActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isFocused
                            ? Color(red: 0.16, green: 0.35, blue: 0.75)
                            : (isPrimary ? Color(red: 0.12, green: 0.44, blue: 0.95) : Color.white.opacity(0.08))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.cyan : Color.white.opacity(0.15), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: isFocused ? Color.cyan.opacity(0.4) : Color.clear, radius: 6)
            .scaleEffect(isFocused ? 1.04 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}
