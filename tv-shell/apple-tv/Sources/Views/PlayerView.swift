import SwiftUI
import AVKit

// MARK: - Audio & Subtitle Track Models
public struct AudioTrackItem: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let option: AVMediaSelectionOption?

    public init(id: String, displayName: String, option: AVMediaSelectionOption?) {
        self.id = id
        self.displayName = displayName
        self.option = option
    }
}

public struct SubtitleTrackItem: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let option: AVMediaSelectionOption?

    public init(id: String, displayName: String, option: AVMediaSelectionOption?) {
        self.id = id
        self.displayName = displayName
        self.option = option
    }
}

public enum ActivePlayerDrawer: String {
    case audio
    case subtitles
    case quickChannels
}

// MARK: - Native tvOS Video Player Layer
public struct PlayerLayerView: UIViewRepresentable {
    public let player: AVPlayer
    public let gravity: AVLayerVideoGravity

    public init(player: AVPlayer, gravity: AVLayerVideoGravity) {
        self.player = player
        self.gravity = gravity
    }

    public func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    public func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = gravity
    }
}

public class PlayerUIView: UIView {
    public override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Comprehensive Player View with In-Player OSD Controls (Option 2)
public struct PlayerView: View {
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    @State private var currentItem: MediaItem
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = true
    @State private var activeDrawer: ActivePlayerDrawer? = nil
    @State private var videoGravity: AVLayerVideoGravity = .resizeAspect
    @State private var toastMessage: String? = nil

    // Tracks
    @State private var audioTracks: [AudioTrackItem] = []
    @State private var selectedAudioId: String? = nil
    @State private var subtitleTracks: [SubtitleTrackItem] = []
    @State private var selectedSubtitleId: String = "off"

    // SubDL
    @State private var subdlSubtitles: [SubDLSubtitleItem] = []
    @State private var isSearchingSubDL: Bool = false
    @State private var selectedSubDLRelease: String? = nil

    // Auto-hide Timer
    @State private var hideTimer: Task<Void, Never>? = nil

    public init(item: MediaItem) {
        _currentItem = State(initialValue: item)
    }

    public var body: some View {
        ZStack {
            // Background Video Canvas
            Color.black.edgesIgnoringSafeArea(.all)

            if let p = player {
                PlayerLayerView(player: p, gravity: videoGravity)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Connecting to stream…")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // OSD Overlay
            if showControls {
                ZStack {
                    // Subtle dark gradient vignette for readable controls
                    VStack {
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)

                        Spacer()

                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 260)
                    }
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)

                    // Top Bar
                    VStack {
                        HStack(alignment: .center, spacing: 20) {
                            // Back Button
                            Button(action: {
                                player?.pause()
                                dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Back")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)

                            // Title & Badges
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 10) {
                                    if currentItem.kind == .live {
                                        HStack(spacing: 5) {
                                            Circle().fill(Color.red).frame(width: 8, height: 8)
                                            Text("LIVE")
                                                .font(.system(size: 11, weight: .black))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.25))
                                        .cornerRadius(4)
                                    }

                                    Text(currentItem.title.cleanedIptvTitle)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }

                                if let plot = currentItem.plot, !plot.isEmpty {
                                    Text(plot)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // Right Action Controls
                            HStack(spacing: 14) {
                                // Audio Tracks Toggle
                                Button(action: {
                                    toggleDrawer(.audio)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "speaker.wave.2.fill")
                                        Text("Audio")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                                .tint(activeDrawer == .audio ? Color.cyan : Color.white.opacity(0.2))

                                // Subtitles Toggle
                                Button(action: {
                                    toggleDrawer(.subtitles)
                                    if activeDrawer == .subtitles && subdlSubtitles.isEmpty {
                                        Task { await searchSubDLSubtitles() }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "captions.bubble.fill")
                                        Text("Subtitles")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                                .tint(activeDrawer == .subtitles ? Color.cyan : Color.white.opacity(0.2))

                                // Aspect Ratio Switcher
                                Button(action: {
                                    cycleAspectRatio()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "aspectratio")
                                        Text(aspectRatioLabel)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)

                                // Quick Channels for Live TV
                                if currentItem.kind == .live {
                                    Button(action: {
                                        toggleDrawer(.quickChannels)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "tv")
                                            Text("Channels")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(activeDrawer == .quickChannels ? Color.cyan : Color.white.opacity(0.2))
                                }
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.top, 36)

                        Spacer()
                    }

                    // Bottom Quick Channel Switcher Strip (Live TV)
                    if currentItem.kind == .live && (activeDrawer == .quickChannels || activeDrawer == nil) {
                        VStack(spacing: 12) {
                            Spacer()

                            HStack {
                                Text("QUICK CHANNEL SWITCHER")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(appState.channels.count) Available")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 48)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(appState.channels.prefix(40)) { ch in
                                        Button(action: {
                                            switchChannel(to: ch)
                                        }) {
                                            HStack(spacing: 10) {
                                                if let logo = ch.logoUrl, let u = URL(string: logo) {
                                                    AsyncImage(url: u) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().scaledToFit()
                                                        } else {
                                                            Image(systemName: "tv")
                                                                .foregroundColor(.white.opacity(0.4))
                                                        }
                                                    }
                                                    .frame(width: 32, height: 32)
                                                } else {
                                                    Image(systemName: "tv")
                                                        .foregroundColor(.white.opacity(0.4))
                                                        .frame(width: 32, height: 32)
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(ch.title.cleanedIptvTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)

                                                    if let cat = ch.categoryName, !cat.isEmpty {
                                                        Text(cat)
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.white.opacity(0.5))
                                                            .lineLimit(1)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(8)
                                            .frame(width: 220, height: 54)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(ch.id == currentItem.id ? Color.cyan : Color.white.opacity(0.15))
                                    }
                                }
                                .padding(.horizontal, 48)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }

            // Right Slide-Over Drawer for Audio / Subtitles
            if let drawer = activeDrawer, drawer != .quickChannels {
                HStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 20) {
                        // Drawer Header
                        HStack {
                            Image(systemName: drawer == .audio ? "speaker.wave.2.fill" : "captions.bubble.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.cyan)
                            Text(drawer == .audio ? "Audio Track Selector" : "Subtitles (Embedded & SubDL)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            Button("Close") {
                                activeDrawer = nil
                                resetHideTimer()
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        if drawer == .audio {
                            // Audio Tracks List
                            if audioTracks.isEmpty {
                                Text("No alternative audio streams detected for this channel.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 20)
                            } else {
                                ScrollView(.vertical) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(audioTracks) { track in
                                            Button(action: {
                                                selectAudioTrack(track)
                                            }) {
                                                HStack {
                                                    Text(track.displayName)
                                                        .font(.system(size: 15, weight: .medium))
                                                    Spacer()
                                                    if selectedAudioId == track.id {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.cyan)
                                                    }
                                                }
                                                .padding(14)
                                                .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        } else if drawer == .subtitles {
                            // Subtitles List
                            ScrollView(.vertical) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("EMBEDDED SUBTITLES")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))

                                    ForEach(subtitleTracks) { track in
                                        Button(action: {
                                            selectSubtitleTrack(track)
                                        }) {
                                            HStack {
                                                Text(track.displayName)
                                                    .font(.system(size: 14, weight: .medium))
                                                Spacer()
                                                if selectedSubtitleId == track.id {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.cyan)
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Text("ONLINE SUBTITLES (SUBDL ENGINE)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.top, 10)

                                    if isSearchingSubDL {
                                        HStack(spacing: 10) {
                                            ProgressView().scaleEffect(0.8)
                                            Text("Searching SubDL database…")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else if subdlSubtitles.isEmpty {
                                        Text("No online subtitles found.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        ForEach(subdlSubtitles.prefix(10)) { sub in
                                            Button(action: {
                                                selectedSubDLRelease = sub.releaseName
                                                showToast("SubDL Subtitles Activated: \(sub.language)")
                                                activeDrawer = nil
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(sub.language.uppercased())
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.cyan.opacity(0.2))
                                                            .foregroundColor(.cyan)
                                                            .cornerRadius(4)
                                                        Spacer()
                                                        if selectedSubDLRelease == sub.releaseName {
                                                            Image(systemName: "checkmark").foregroundColor(.cyan)
                                                        }
                                                    }
                                                    Text(sub.releaseName)
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                }
                                                .padding(10)
                                                .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(32)
                    .frame(width: 480)
                    .background(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.96))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.trailing, 40)
                    .padding(.vertical, 30)
                }
                .edgesIgnoringSafeArea(.all)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Toast HUD Message
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.cyan)
                        Text(toast)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.bottom, 140)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Remote click capture surface when controls are hidden
            if !showControls {
                Button(action: {
                    withAnimation {
                        showControls = true
                        resetHideTimer()
                    }
                }) {
                    Color.clear
                }
                .buttonStyle(.plain)
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            startStream(url: currentItem.streamUrl)
            resetHideTimer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            hideTimer?.cancel()
        }
        .onPlayPauseCommand {
            togglePlayPause()
        }
    }

    // MARK: - Stream & Channel Actions
    private func startStream(url: String) {
        guard let u = URL(string: url) else { return }
        let asset = AVURLAsset(url: u, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": "IPTVSmartersPro"]])
        let playerItem = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: playerItem)
        self.player = p
        p.play()
        self.isPlaying = true

        // Load media options once item is ready
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let item = p.currentItem {
                self.loadTracks(from: item)
            }
        }
    }

    private func switchChannel(to channel: MediaItem) {
        self.currentItem = channel
        appState.addToHistory(channel)
        showToast("Switched to \(channel.title.cleanedIptvTitle)")
        if let u = URL(string: channel.streamUrl) {
            let asset = AVURLAsset(url: u, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": "IPTVSmartersPro"]])
            let playerItem = AVPlayerItem(asset: asset)
            let p = AVPlayer(playerItem: playerItem)
            self.player = p
            p.play()
            self.isPlaying = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if let item = p.currentItem {
                    self.loadTracks(from: item)
                }
            }
        }
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
            showToast("Paused")
            showControls = true
            hideTimer?.cancel()
        } else {
            p.play()
            isPlaying = true
            showToast("Playing")
            resetHideTimer()
        }
    }

    private func cycleAspectRatio() {
        if videoGravity == .resizeAspect {
            videoGravity = .resizeAspectFill
            showToast("Aspect Ratio: Fill (Zoom)")
        } else if videoGravity == .resizeAspectFill {
            videoGravity = .resize
            showToast("Aspect Ratio: Stretch")
        } else {
            videoGravity = .resizeAspect
            showToast("Aspect Ratio: Fit 16:9")
        }
        resetHideTimer()
    }

    private var aspectRatioLabel: String {
        switch videoGravity {
        case .resizeAspect: return "16:9 Fit"
        case .resizeAspectFill: return "Fill Zoom"
        case .resize: return "Stretch"
        default: return "Fit"
        }
    }

    private func toggleDrawer(_ drawer: ActivePlayerDrawer) {
        if activeDrawer == drawer {
            activeDrawer = nil
            resetHideTimer()
        } else {
            activeDrawer = drawer
            hideTimer?.cancel()
        }
    }

    private func resetHideTimer() {
        hideTimer?.cancel()
        hideTimer = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if activeDrawer == nil {
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Audio & Subtitle Handling
    private func loadTracks(from item: AVPlayerItem) {
        let asset = item.asset

        // Audio Tracks
        if let audioGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            var audios: [AudioTrackItem] = []
            for opt in audioGroup.options {
                audios.append(AudioTrackItem(id: opt.displayName, displayName: opt.displayName, option: opt))
            }
            self.audioTracks = audios
            self.selectedAudioId = item.currentMediaSelection.selectedMediaOption(in: audioGroup)?.displayName
        }

        // Subtitle Tracks
        if let subGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            var subs: [SubtitleTrackItem] = [SubtitleTrackItem(id: "off", displayName: "Off", option: nil)]
            for opt in subGroup.options {
                subs.append(SubtitleTrackItem(id: opt.displayName, displayName: opt.displayName, option: opt))
            }
            self.subtitleTracks = subs
            self.selectedSubtitleId = item.currentMediaSelection.selectedMediaOption(in: subGroup)?.displayName ?? "off"
        }
    }

    private func selectAudioTrack(_ track: AudioTrackItem) {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        if let opt = track.option {
            item.select(opt, in: group)
        }
        selectedAudioId = track.id
        showToast("Audio: \(track.displayName)")
    }

    private func selectSubtitleTrack(_ track: SubtitleTrackItem) {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if let opt = track.option {
            item.select(opt, in: group)
        } else {
            item.select(nil, in: group)
        }
        selectedSubtitleId = track.id
        showToast("Subtitles: \(track.displayName)")
    }

    private func searchSubDLSubtitles() async {
        isSearchingSubDL = true
        let results = await SubDLService.searchSubtitles(title: currentItem.title.cleanedIptvTitle)
        self.subdlSubtitles = results
        self.isSearchingSubDL = false
    }
}
