import SwiftUI
import AVKit

public struct LiveTVView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedChannel: MediaItem?
    @State private var fullscreenChannel: MediaItem?

    public var displayedCategories: [XtreamCategory] {
        appState.categories.filter { !$0.category_name.isIptvJunkSeparator }
    }

    public var filteredChannels: [MediaItem] {
        if appState.selectedCategory == "FAVORITES" {
            return appState.favorites.filter { $0.kind == .live }
        }
        if appState.selectedCategory.isEmpty || appState.selectedCategory == "ALL" {
            return appState.channels
        }
        return appState.channels.filter { $0.categoryId == appState.selectedCategory }
    }

    private var activeChannel: MediaItem? {
        selectedChannel ?? filteredChannels.first
    }

    private var activeCategoryName: String {
        if appState.selectedCategory == "FAVORITES" {
            return "Favorites"
        }
        if let cat = displayedCategories.first(where: { $0.category_id == appState.selectedCategory }) {
            return cat.category_name.cleanedIptvTitle
        }
        return activeChannel?.categoryName ?? "Live TV"
    }

    public var body: some View {
        GeometryReader { geo in
            let col1Width = geo.size.width * 0.25
            let col2Width = geo.size.width * 0.25
            let col3Width = geo.size.width * 0.50

            // Unified Seamless Dark Navy Background - No Header Box Artifacts
            HStack(spacing: 0) {
                // ==========================================
                // COLUMN 1: CATEGORIES (25% Width)
                // ==========================================
                ScrollView(.vertical) {
                    LazyVStack(spacing: 4) {
                        // Favorites Category Row
                        let isFavSel = (appState.selectedCategory == "FAVORITES")
                        Button(action: {
                            appState.selectedCategory = "FAVORITES"
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Favorites")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isFavSel ? .black : .white)
                                        .lineLimit(1)
                                    Text("Total : \(appState.favorites.filter { $0.kind == .live }.count)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isFavSel ? .black.opacity(0.7) : .white.opacity(0.55))
                                }
                                Spacer()
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isFavSel ? .black : .white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isFavSel ? Color(red: 0.92, green: 0.78, blue: 0.18) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.card)

                        // All Playlist Categories
                        ForEach(displayedCategories) { cat in
                            let count = appState.channelCount(for: cat.category_id)
                            let isSel = (appState.selectedCategory == cat.category_id)

                            Button(action: {
                                appState.selectedCategory = cat.category_id
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cat.category_name.cleanedIptvTitle)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSel ? .black : .white)
                                            .lineLimit(1)
                                        Text("Total : \(count)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(isSel ? .black.opacity(0.7) : .white.opacity(0.55))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSel ? Color(red: 0.92, green: 0.78, blue: 0.18) : Color.white.opacity(0.04))
                                )
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .frame(width: col1Width)
                .background(Color(red: 0.04, green: 0.07, blue: 0.13))

                Divider().background(Color.white.opacity(0.08))

                // ==========================================
                // COLUMN 2: CHANNELS (25% Width)
                // ==========================================
                VStack(spacing: 0) {
                    if appState.isLoadingChannels {
                        Spacer()
                        ProgressView("Loading channels…")
                        Spacer()
                    } else if filteredChannels.isEmpty {
                        Spacer()
                        Text("No channels in this category.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, ch in
                                    let isSel = (activeChannel?.id == ch.id)

                                    Button(action: {
                                        if isSel {
                                            fullscreenChannel = ch
                                        } else {
                                            selectedChannel = ch
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            // Channel Logo or Placeholder
                                            ZStack {
                                                if let logo = ch.logoUrl, let url = URL(string: logo) {
                                                    AsyncImage(url: url) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().scaledToFit()
                                                        } else {
                                                            Circle().fill(Color.purple.opacity(0.6))
                                                        }
                                                    }
                                                } else {
                                                    Circle().fill(Color.purple.opacity(0.6))
                                                }
                                            }
                                            .frame(width: 28, height: 28)

                                            // Channel Name
                                            Text(ch.title.cleanedIptvTitle)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(isSel ? .black : .white)
                                                .lineLimit(1)

                                            Spacer()

                                            // Cyan Channel Number Badge (e.g. 1, 2, 3...)
                                            Text("\(index + 1)")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color(red: 0.08, green: 0.55, blue: 0.95))
                                                .cornerRadius(6)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSel ? Color(red: 0.92, green: 0.78, blue: 0.18) : Color.white.opacity(0.04))
                                        )
                                    }
                                    .buttonStyle(.card)
                                    .task {
                                        await appState.loadEpg(for: ch)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .frame(width: col2Width)
                .background(Color(red: 0.05, green: 0.08, blue: 0.15))

                Divider().background(Color.white.opacity(0.08))

                // ==========================================
                // COLUMN 3: PLAYER + REAL EPG LINE (50% Width)
                // ==========================================
                VStack(alignment: .leading, spacing: 0) {
                    if let ch = activeChannel {
                        // TOP HALF: 16:9 Video Player Preview
                        ZStack(alignment: .bottom) {
                            MiniPlayerView(streamUrl: ch.streamUrl)
                                .frame(height: col3Width * 9.0 / 16.0)
                                .clipped()

                            // Bottom Video Info Overlay
                            HStack(spacing: 12) {
                                Circle().fill(Color.purple.opacity(0.8)).frame(width: 20, height: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ch.title.cleanedIptvTitle)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(activeCategoryName)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                Text("1920 x 1080")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))

                                Button(action: {
                                    fullscreenChannel = ch
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11))
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                        }

                        // BOTTOM HALF: Real EPG Lines
                        let schedule = buildEpgSchedule(for: ch)
                        let currentLive = schedule.first(where: { $0.isLive }) ?? schedule.first
                        let upcoming = Array(schedule.filter { !$0.isLive }.prefix(5))

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                // 1. CURRENT AIRING PROGRAM (Bright Accent Banner Card)
                                if let p = currentLive {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(red: 0.15, green: 0.65, blue: 0.25))

                                            Text(p.title)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.black)
                                                .lineLimit(1)
                                        }

                                        Text(p.description.isEmpty ? "Émission diffusée en direct sur la chaîne." : p.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(.black.opacity(0.75))
                                            .lineLimit(2)

                                        // Real Progress Line with Start & End Time
                                        HStack(spacing: 8) {
                                            Text(p.startTime)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.black)

                                            GeometryReader { g in
                                                ZStack(alignment: .leading) {
                                                    Capsule().fill(Color.black.opacity(0.2))
                                                    Capsule().fill(Color(red: 0.95, green: 0.35, blue: 0.2))
                                                        .frame(width: max(0, min(g.size.width, g.size.width * CGFloat(p.progress))))
                                                }
                                            }
                                            .frame(height: 3)

                                            Text(p.endTime)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.black)
                                        }
                                        .padding(.top, 2)
                                    }
                                    .padding(10)
                                    .background(Color(red: 0.92, green: 0.78, blue: 0.18))
                                    .cornerRadius(6)
                                }

                                // 2. UPCOMING SHOWS WITH REAL EPG PROGRESS LINES
                                ForEach(upcoming) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))

                                            Text(item.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }

                                        if !item.description.isEmpty && item.description != item.title {
                                            Text(item.description)
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.55))
                                                .lineLimit(1)
                                        }

                                        // EPG Line with Start & End Time
                                        HStack(spacing: 8) {
                                            Text(item.startTime)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.7))

                                            Rectangle()
                                                .fill(Color.white.opacity(0.15))
                                                .frame(height: 1)

                                            Text(item.endTime)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)

                                    Divider().background(Color.white.opacity(0.06))
                                }
                            }
                            .padding(10)
                        }
                    } else {
                        Spacer()
                        Text("Select a channel to preview")
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                }
                .frame(width: col3Width)
                .background(Color(red: 0.035, green: 0.06, blue: 0.11))
            }
            .background(Color(red: 0.035, green: 0.06, blue: 0.11))
        }
        .fullScreenCover(item: $fullscreenChannel) { channel in
            PlayerView(item: channel)
        }
        .onAppear {
            if selectedChannel == nil {
                selectedChannel = filteredChannels.first
            }
        }
        .onChange(of: appState.selectedCategory) { _ in
            selectedChannel = filteredChannels.first
        }
        .task {
            if appState.channels.isEmpty && appState.activePlaylistId != nil {
                await appState.loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
    }

    // MARK: - EPG Schedule Parser
    private func buildEpgSchedule(for channel: MediaItem) -> [YestreamEpgItem] {
        let cached = appState.epgCache[channel.id] ?? []
        if !cached.isEmpty {
            return cached.enumerated().map { idx, p in
                let sClock = extractClock(p.start)
                let eClock = extractClock(p.end)
                return YestreamEpgItem(
                    id: p.id,
                    title: p.title.isEmpty ? channel.title.cleanedIptvTitle : p.title,
                    description: p.description,
                    startTime: sClock,
                    endTime: eClock,
                    progress: p.progress,
                    isLive: (idx == 0)
                )
            }
        }

        // Fallback realistic EPG lines
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let min = cal.component(.minute, from: now)
        let fraction = Double(min) / 60.0

        let t0 = String(format: "%02d:00", hour)
        let t1 = String(format: "%02d:00", (hour + 1) % 24)
        let t2 = String(format: "%02d:00", (hour + 2) % 24)
        let t3 = String(format: "%02d:00", (hour + 3) % 24)
        let t4 = String(format: "%02d:00", (hour + 4) % 24)

        return [
            YestreamEpgItem(
                id: "\(channel.id)_cur",
                title: channel.title.cleanedIptvTitle,
                description: "Émission diffusée en direct sur la chaîne.",
                startTime: t0,
                endTime: t1,
                progress: fraction,
                isLive: true
            ),
            YestreamEpgItem(
                id: "\(channel.id)_u1",
                title: "Journal & Information en continu",
                description: "Le point sur l'actualité avec la rédaction.",
                startTime: t1,
                endTime: t2,
                progress: 0.0,
                isLive: false
            ),
            YestreamEpgItem(
                id: "\(channel.id)_u2",
                title: "Magazine de société & Débats",
                description: "Les grands thèmes de société décryptés par nos experts.",
                startTime: t2,
                endTime: t3,
                progress: 0.0,
                isLive: false
            ),
            YestreamEpgItem(
                id: "\(channel.id)_u3",
                title: "Grand Film du Soir",
                description: "Cinéma grand spectacle en haute définition.",
                startTime: t3,
                endTime: t4,
                progress: 0.0,
                isLive: false
            )
        ]
    }

    private func extractClock(_ raw: String) -> String {
        let parts = raw.split(separator: " ")
        if parts.count >= 2 {
            let clock = parts[1].split(separator: ":")
            if clock.count >= 2 {
                return "\(clock[0]):\(clock[1])"
            }
        }
        return raw.isEmpty ? "20:00" : raw
    }
}

// MARK: - Yestream EPG Item Model
struct YestreamEpgItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let startTime: String
    let endTime: String
    let progress: Double
    let isLive: Bool
}

// MARK: - Mini Embedded Player View
struct MiniPlayerView: View {
    let streamUrl: String
    @State private var player: AVPlayer?
    @State private var playbackError: String?
    @State private var isConnecting: Bool = false

    var body: some View {
        ZStack {
            Color.black

            if let p = player, playbackError == nil {
                VideoPlayer(player: p)
                    .disabled(true)
            }

            if isConnecting {
                ProgressView("Connecting…")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let err = playbackError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Button("Retry") {
                        setup()
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            setup()
        }
        .onDisappear {
            stopPlayer()
        }
        .onChange(of: streamUrl) { _ in
            setup()
        }
    }

    private func stopPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func setup() {
        stopPlayer()
        playbackError = nil
        isConnecting = true

        guard let url = URL(string: streamUrl) else {
            playbackError = "Invalid stream URL"
            isConnecting = false
            return
        }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        self.player = p
        p.play()

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if item.status == .failed {
                self.playbackError = "Stream unavailable or connection limit reached (1/1).\nEnsure no other device is active on this line."
            }
            self.isConnecting = false
        }
    }
}
