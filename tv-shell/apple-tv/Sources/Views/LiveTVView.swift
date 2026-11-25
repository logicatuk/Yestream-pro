import SwiftUI
import AVKit

public struct LiveTVView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedChannel: MediaItem?
    @State private var fullscreenChannel: MediaItem?

    // Filter states
    @State private var categoryFilterText: String = ""
    @State private var categoryQuickPill: CategoryQuickPill = .all
    @State private var channelFilterText: String = ""
    @State private var qualityFilterOnlyHD: Bool = false

    enum CategoryQuickPill: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case recent = "Recent"
    }

    // Cleaned & Filtered Categories
    public var displayedCategories: [XtreamCategory] {
        var list = appState.categories.filter { !$0.category_name.isIptvJunkSeparator }
        if !categoryFilterText.isEmpty {
            list = list.filter { $0.category_name.cleanedIptvTitle.localizedCaseInsensitiveContains(categoryFilterText) }
        }
        return list
    }

    // Cleaned & Filtered Channels
    public var filteredChannels: [MediaItem] {
        var base: [MediaItem] = []

        if categoryQuickPill == .favorites || appState.selectedCategory == "FAVORITES" {
            base = appState.favorites.filter { $0.kind == .live }
        } else if categoryQuickPill == .recent {
            base = appState.history.filter { $0.kind == .live }
        } else if appState.selectedCategory.isEmpty || appState.selectedCategory == "ALL" {
            base = appState.channels
        } else {
            base = appState.channels.filter { $0.categoryId == appState.selectedCategory }
        }

        // Search text filter
        if !channelFilterText.isEmpty {
            base = base.filter { $0.title.cleanedIptvTitle.localizedCaseInsensitiveContains(channelFilterText) }
        }

        // Quality HD/4K toggle
        if qualityFilterOnlyHD {
            base = base.filter {
                let t = $0.title.uppercased()
                return t.contains("4K") || t.contains("FHD") || t.contains("HD") || t.contains("HEVC")
            }
        }

        return base
    }

    private var activeChannel: MediaItem? {
        selectedChannel ?? filteredChannels.first
    }

    public var body: some View {
        GeometryReader { geo in
            let col1Width = geo.size.width * 0.30
            let col2Width = geo.size.width * 0.30
            let col3Width = geo.size.width * 0.40

            HStack(spacing: 0) {
                // ==========================================
                // COLUMN 1: CATEGORIES (30% Width)
                // ==========================================
                VStack(spacing: 12) {
                    // Header Bar with Back to Home Button
                    HStack(spacing: 8) {
                        Button(action: {
                            appState.currentDestination = .home
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Home")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("CATEGORIES")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                    // Pinned Top Filter & Siri Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 14))

                        TextField("Filter categories...", text: $categoryFilterText)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)

                    // Quick Pills: All, Favorites, Recent
                    HStack(spacing: 6) {
                        ForEach(CategoryQuickPill.allCases, id: \.self) { pill in
                            Button(action: {
                                categoryQuickPill = pill
                                if pill == .favorites {
                                    appState.selectedCategory = "FAVORITES"
                                } else if pill == .all {
                                    appState.selectedCategory = "ALL"
                                }
                            }) {
                                Text(pill.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(categoryQuickPill == pill ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                    .foregroundColor(categoryQuickPill == pill ? .white : .white.opacity(0.7))
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)

                    // Clean Category List
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 4) {
                            ForEach(displayedCategories) { cat in
                                let count = appState.channelCount(for: cat.category_id)
                                let isSel = (appState.selectedCategory == cat.category_id && categoryQuickPill == .all)

                                Button(action: {
                                    categoryQuickPill = .all
                                    appState.selectedCategory = cat.category_id
                                }) {
                                    HStack(spacing: 8) {
                                        Text(cat.category_name.cleanedIptvTitle)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(count)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(6)

                                        if isSel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSel ? Color.white.opacity(0.12) : Color.clear)
                                    )
                                }
                                .buttonStyle(.card)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
                .frame(width: col1Width)
                .background(Color(red: 0.05, green: 0.05, blue: 0.07))

                Divider().background(Color.white.opacity(0.08))

                // ==========================================
                // COLUMN 2: CHANNELS WITH FILTER (30% Width)
                // ==========================================
                VStack(spacing: 12) {
                    // Top Filter Input + HD/4K Quality Toggle
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 13))

                            TextField("Filter channels...", text: $channelFilterText)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                        // HD/4K Pill Toggle
                        Button(action: {
                            qualityFilterOnlyHD.toggle()
                        }) {
                            Text("HD/4K")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(qualityFilterOnlyHD ? Color.white.opacity(0.25) : Color.white.opacity(0.06))
                                .foregroundColor(qualityFilterOnlyHD ? .white : .white.opacity(0.6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                    // Channels List (Compact 68pt Rows)
                    if appState.isLoadingChannels {
                        Spacer()
                        ProgressView("Loading channels…")
                        Spacer()
                    } else if filteredChannels.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tv.slash")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No channels match filter")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 6) {
                                ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, ch in
                                    CompactChannelRow(
                                        channel: ch,
                                        index: index + 1,
                                        isSelected: (activeChannel?.id == ch.id),
                                        onSelect: {
                                            selectedChannel = ch
                                        },
                                        onPlayFullscreen: {
                                            fullscreenChannel = ch
                                        }
                                    )
                                    .task {
                                        await appState.loadEpg(for: ch)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(width: col2Width)
                .background(Color(red: 0.04, green: 0.04, blue: 0.06))

                Divider().background(Color.white.opacity(0.08))

                // ==========================================
                // COLUMN 3: FLOATING PLAYER + VERTICAL EPG (40%)
                // ==========================================
                VStack(alignment: .leading, spacing: 14) {
                    if let ch = activeChannel {
                        // TOP HALF: 16:9 Borderless Rounded Video Preview (16pt radius)
                        ZStack(alignment: .bottomTrailing) {
                            MiniPlayerView(streamUrl: ch.streamUrl)
                                .frame(height: col3Width * 9.0 / 16.0)
                                .cornerRadius(16)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )

                            // Subtle Bottom-Right Full Screen Glass Pill
                            Button(action: {
                                fullscreenChannel = ch
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11))
                                    Text("Full Screen")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.black.opacity(0.75))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }

                        // BOTTOM HALF: Vertical EPG Timeline Guide
                        let schedule = buildSchedule(for: ch)
                        let currentProg = schedule.first(where: { $0.isLive }) ?? schedule.first
                        let upcomingProgs = Array(schedule.filter { !$0.isLive }.prefix(5))

                        VStack(alignment: .leading, spacing: 12) {
                            // 1. Now Playing Header Card
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    // Live Badge
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 5, height: 5)
                                        Text("EN DIRECT")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(4)

                                    Text(ch.title.cleanedIptvTitle)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Spacer()

                                    if let p = currentProg {
                                        Text(p.timeRange)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }

                                if let p = currentProg {
                                    Text(p.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(p.description.isEmpty ? "Retrouvez votre émission en direct sur \(ch.title.cleanedIptvTitle)." : p.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.65))
                                        .lineLimit(2)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                            // 2. Up Next Vertical Timeline Header
                            Text("À SUIVRE / UP NEXT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)

                            // 3. Scrollable Vertical Timeline Rows with Left Connecting Line
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(upcomingProgs.enumerated()), id: \.element.id) { idx, item in
                                        VerticalTimelineRow(
                                            item: item,
                                            isLast: idx == upcomingProgs.count - 1
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        Spacer()
                        Text("Select a channel to preview")
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                }
                .frame(width: col3Width)
                .padding(.horizontal, 16)
                .background(Color(red: 0.03, green: 0.03, blue: 0.05))
            }
        }
        .fullScreenCover(item: $fullscreenChannel) { channel in
            PlayerView(item: channel)
        }
        .onExitCommand {
            appState.currentDestination = .home
        }
        .onChange(of: appState.selectedCategory) { _ in
            selectedChannel = filteredChannels.first
        }
        .onAppear {
            if selectedChannel == nil {
                selectedChannel = filteredChannels.first
            }
        }
        .task {
            if appState.channels.isEmpty && appState.activePlaylistId != nil {
                await appState.loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
    }

    // MARK: - Schedule Builder (Xtream EPG + Fallback)
    private func buildSchedule(for channel: MediaItem) -> [VerticalEpgItem] {
        let cached = appState.epgCache[channel.id] ?? []
        if !cached.isEmpty {
            return cached.enumerated().map { index, p in
                let sClock = extractClock(p.start)
                let eClock = extractClock(p.end)
                return VerticalEpgItem(
                    id: p.id,
                    title: p.title.isEmpty ? channel.title.cleanedIptvTitle : p.title,
                    description: p.description,
                    startTime: sClock,
                    endTime: eClock,
                    timeRange: "\(sClock) – \(eClock)",
                    isLive: (index == 0)
                )
            }
        }

        // Realistic Fallback
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let t0 = String(format: "%02d:00", hour)
        let t1 = String(format: "%02d:45", hour)
        let t2 = String(format: "%02d:30", (hour + 1) % 24)
        let t3 = String(format: "%02d:00", (hour + 2) % 24)
        let t4 = String(format: "%02d:30", (hour + 3) % 24)

        return [
            VerticalEpgItem(
                id: "\(channel.id)_live",
                title: channel.title.cleanedIptvTitle,
                description: "Émission diffusée en continu.",
                startTime: t0,
                endTime: t1,
                timeRange: "\(t0) – \(t1)",
                isLive: true
            ),
            VerticalEpgItem(
                id: "\(channel.id)_next1",
                title: "Journal & Magazine d'information",
                description: "Le point complet sur l'actualité nationale et internationale.",
                startTime: t1,
                endTime: t2,
                timeRange: "\(t1) – \(t2)",
                isLive: false
            ),
            VerticalEpgItem(
                id: "\(channel.id)_next2",
                title: "Soirée Divertissement & Débat",
                description: "Grand format avec les invités de la rédaction.",
                startTime: t2,
                endTime: t3,
                timeRange: "\(t2) – \(t3)",
                isLive: false
            ),
            VerticalEpgItem(
                id: "\(channel.id)_next3",
                title: "Grand Film du Soir",
                description: "Cinéma en haute définition.",
                startTime: t3,
                endTime: t4,
                timeRange: "\(t3) – \(t4)",
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
        return raw.isEmpty ? "21:00" : raw
    }
}

// MARK: - Vertical EPG Item Model
public struct VerticalEpgItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let startTime: String
    public let endTime: String
    public let timeRange: String
    public let isLive: Bool
}

// MARK: - Compact Channel Row (68pt Height)
struct CompactChannelRow: View {
    @ObservedObject var appState = AppState.shared
    let channel: MediaItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlayFullscreen: () -> Void

    var body: some View {
        Button(action: {
            if isSelected {
                onPlayFullscreen()
            } else {
                onSelect()
            }
        }) {
            HStack(spacing: 12) {
                // Crisp channel logo inside neutral dark squircle (44pt x 44pt)
                ZStack {
                    if let logo = channel.logoUrl, let url = URL(string: logo) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Text("\(index)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    } else {
                        Text("\(index)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Title + Current Program + Thin 2pt Monochrome Progress Bar
                let curProg = appState.epgCache[channel.id]?.first
                let progTitle = curProg?.title ?? channel.categoryName ?? "En direct"
                let progress = curProg?.progress ?? 0.45

                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.title.cleanedIptvTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(progTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    // Thin 2pt Monochrome White/Silver Progress Bar
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color.white.opacity(0.85))
                                .frame(width: max(0, min(g.size.width, g.size.width * CGFloat(progress))))
                        }
                    }
                    .frame(height: 2)
                    .padding(.top, 2)
                }

                Spacer()

                // Subtle Favorite Heart Icon
                Button(action: {
                    appState.toggleFavorite(channel)
                }) {
                    Image(systemName: appState.isFavorite(channel) ? "heart.fill" : "heart")
                        .foregroundColor(appState.isFavorite(channel) ? .red : .white.opacity(0.35))
                        .font(.system(size: 13))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.card)
        .onPlayPauseCommand {
            appState.toggleFavorite(channel)
        }
    }
}

// MARK: - Vertical EPG Timeline Row (With Connecting Line)
struct VerticalTimelineRow: View {
    let item: VerticalEpgItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Time Pin (21:00, 22:45...)
            Text(item.startTime)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 48, alignment: .trailing)

            // Vertical Connecting Line with Circle Node
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2)
                        .frame(minHeight: 38)
                }
            }

            // Show Title & Description
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.timeRange)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 12)

            Spacer()
        }
    }
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
