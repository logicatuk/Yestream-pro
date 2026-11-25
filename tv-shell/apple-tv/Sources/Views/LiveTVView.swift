import SwiftUI
import AVKit

public struct LiveTVView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedChannel: MediaItem?
    @State private var fullscreenChannel: MediaItem?

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

    public var body: some View {
        HStack(spacing: 0) {
            // ==========================================
            // COLUMN 1: CATEGORIES SIDEBAR (Width: 350)
            // ==========================================
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    // 1. FAVORITES CATEGORY
                    Button(action: {
                        appState.selectedCategory = "FAVORITES"
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            Text("Favorites")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            let favCount = appState.channelCount(for: "FAVORITES")
                            Text("\(favCount)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.yellow)
                                .cornerRadius(6)
                            if appState.selectedCategory == "FAVORITES" {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    // 2. ALL CHANNELS
                    Button(action: {
                        appState.selectedCategory = "ALL"
                    }) {
                        HStack {
                            Text("All Channels")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text("\(appState.channelCount(for: "ALL"))")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                            if appState.selectedCategory == "ALL" || appState.selectedCategory.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    Divider().padding(.vertical, 4)

                    // 3. CATEGORIES LIST
                    ForEach(appState.categories) { cat in
                        Button(action: {
                            appState.selectedCategory = cat.category_id
                        }) {
                            HStack {
                                Text(cat.category_name)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer()
                                let count = appState.channelCount(for: cat.category_id)
                                Text("\(count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(6)
                                if cat.category_id == appState.selectedCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(width: 350)

            Divider()

            // ==========================================
            // COLUMN 2: CHANNELS LIST (Width: 460)
            // ==========================================
            VStack(spacing: 0) {
                if appState.isLoadingChannels {
                    Spacer()
                    ProgressView("Loading channels…")
                    Spacer()
                } else if filteredChannels.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: appState.selectedCategory == "FAVORITES" ? "heart.slash" : "tv.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(appState.selectedCategory == "FAVORITES" ? "No favorite channels yet." : "No channels available.")
                            .font(.headline)
                        Text(appState.selectedCategory == "FAVORITES" ? "Add channels to favorites by clicking the heart icon." : "Select another category.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, ch in
                                ChannelRowItem(
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
                        .padding(.vertical, 10)
                    }
                }
            }
            .frame(width: 480)

            Divider()

            // ==========================================
            // COLUMN 3: LIVE PREVIEW & EPG TIMELINE
            // ==========================================
            VStack(alignment: .leading, spacing: 16) {
                if let ch = activeChannel {
                    // TOP: Embedded Live Player Preview
                    ZStack(alignment: .bottomTrailing) {
                        MiniPlayerView(streamUrl: ch.streamUrl)
                            .frame(height: 320)
                            .cornerRadius(16)
                            .clipped()

                        // Fullscreen Button Overlay
                        Button(action: {
                            fullscreenChannel = ch
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                Text("Full Screen")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }

                    // BOTTOM: Channel Details & EPG Guide Timeline
                    VStack(alignment: .leading, spacing: 12) {
                        // Channel Header
                        HStack(spacing: 14) {
                            if let logo = ch.logoUrl, let url = URL(string: logo) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFit()
                                    } else {
                                        Image(systemName: "tv").font(.title2)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                    Text("LIVE NOW")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.red)
                                }
                                Text(ch.title)
                                    .font(.title3)
                                    .fontWeight(.heavy)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: {
                                appState.toggleFavorite(ch)
                            }) {
                                Image(systemName: appState.isFavorite(ch) ? "heart.fill" : "heart")
                                    .foregroundColor(appState.isFavorite(ch) ? .red : .white)
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                        }

                        // Current Program EPG Card
                        let curProg = appState.epgCache[ch.id]?.first
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(curProg?.title ?? ch.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                if let range = curProg?.formattedTimeRange, !range.isEmpty {
                                    Text(range)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                                }
                            }

                            if let p = curProg {
                                // Elapsed Progress Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.15))
                                        Capsule().fill(Color.blue)
                                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(p.progress))))
                                    }
                                }
                                .frame(height: 5)

                                if !p.description.isEmpty && p.description != p.title {
                                    Text(p.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)

                        // Upcoming Schedule
                        let upcoming = Array((appState.epgCache[ch.id] ?? []).dropFirst().prefix(4))
                        if !upcoming.isEmpty {
                            Text("À SUIVRE / UP NEXT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)

                            VStack(spacing: 6) {
                                ForEach(upcoming) { item in
                                    HStack {
                                        Text(item.formattedTimeRange)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .frame(width: 110, alignment: .leading)
                                        Text(item.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                } else {
                    Spacer()
                    Text("Select a channel to preview")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .fullScreenCover(item: $fullscreenChannel) { channel in
            PlayerView(item: channel)
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
}

// MARK: - Channel Row Item Component
struct ChannelRowItem: View {
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
                // Channel Logo
                if let logo = channel.logoUrl, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else {
                            Image(systemName: "tv").font(.system(size: 16))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                } else {
                    Image(systemName: "tv")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }

                // Title + EPG show + Progress
                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    let epg = appState.epgCache[channel.id]?.first
                    Text(epg?.title ?? channel.categoryName ?? "Live")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let p = epg, !p.formattedTimeRange.isEmpty {
                        HStack(spacing: 6) {
                            Text(p.formattedTimeRange)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            // Mini progress bar
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.15))
                                    Capsule().fill(Color.blue)
                                        .frame(width: max(0, min(g.size.width, g.size.width * CGFloat(p.progress))))
                                }
                            }
                            .frame(width: 70, height: 3)
                        }
                    }
                }

                Spacer()

                // Heart Favorite Button
                Button(action: {
                    appState.toggleFavorite(channel)
                }) {
                    Image(systemName: appState.isFavorite(channel) ? "heart.fill" : "heart")
                        .foregroundColor(appState.isFavorite(channel) ? .red : .white.opacity(0.35))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 64)
        }
        .buttonStyle(.card)
    }
}

// MARK: - Mini Embedded Player View
struct MiniPlayerView: View {
    let streamUrl: String
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .disabled(true)
            } else {
                Color.black
                ProgressView()
            }
        }
        .onAppear {
            setup()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: streamUrl) { _ in
            setup()
        }
    }

    private func setup() {
        player?.pause()
        guard let url = URL(string: streamUrl) else {
            player = nil
            return
        }
        player = AVPlayer(url: url)
        player?.play()
    }
}
