import SwiftUI

// MARK: - Device Expired / Activation Gate View
public struct DeviceExpiredView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cloud = CloudSyncService.shared
    @ObservedObject var appState = AppState.shared

    public var onOpenPlaylists: (() -> Void)? = nil

    @FocusState private var focusedButton: ExpiredButtonFocus?
    enum ExpiredButtonFocus: Hashable {
        case back
        case refresh
        case playlists
    }

    @State private var isChecking: Bool = false
    @State private var checkResultMessage: String = ""

    public init(onOpenPlaylists: (() -> Void)? = nil) {
        self.onOpenPlaylists = onOpenPlaylists
    }

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

            VStack(spacing: 32) {
                // ==========================================
                // 1. BRAND HEADER (Authentic Yestream Logo & Typography)
                // ==========================================
                HStack(spacing: 14) {
                    if let uiImage = UIImage(named: "logo") ?? (Bundle.main.path(forResource: "logo", ofType: "png").flatMap { UIImage(contentsOfFile: $0) }) ?? UIImage(contentsOfFile: Bundle.main.bundlePath + "/logo.png") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                    } else {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YESTREAM")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .tracking(2.0)
                            .foregroundColor(.white)
                        Text("PRO IPTV PLAYER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(3.0)
                            .foregroundColor(Color(red: 0.3, green: 0.65, blue: 1.0))
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
                            Text("https://yestream.ai.studio/")
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
                // 4. ACTION BUTTONS: Refresh Status & Playlists (Standard tvOS Bordered)
                // ==========================================
                HStack(spacing: 28) {
                    Button(action: {
                        Task {
                            await checkStatus()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(isChecking ? "Checking…" : "Refresh Status")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(width: 200, height: 48)
                    }
                    .buttonStyle(.bordered)
                    .focused($focusedButton, equals: .refresh)
                    .disabled(isChecking)

                    Button(action: {
                        if let onOpenPlaylists = onOpenPlaylists {
                            onOpenPlaylists()
                        } else {
                            dismiss()
                            appState.selectedTab = 5
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14, weight: .bold))
                            Text("Manage Playlists")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(width: 200, height: 48)
                    }
                    .buttonStyle(.bordered)
                    .focused($focusedButton, equals: .playlists)

                    if cloud.registration?.isExpired == false {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Exit Preview")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(width: 170, height: 48)
                        }
                        .buttonStyle(.bordered)
                        .focused($focusedButton, equals: .back)
                    }
                }

                if !checkResultMessage.isEmpty {
                    Text(checkResultMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.cyan)
                        .animation(.easeInOut, value: checkResultMessage)
                }

                Spacer()
            }
            .padding(.horizontal, 48)
        }
        .onAppear {
            focusedButton = .refresh
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
