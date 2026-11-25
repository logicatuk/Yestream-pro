import SwiftUI
import AVKit

public struct LiveTVView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedChannel: MediaItem?
    @State private var fullscreenChannel: MediaItem?
    @State private var selectedProgramForDetails: EpgScheduleItem?
    @State private var selectedDateOffset: Int = 0 // 0 = Today, +1 = Tomorrow, -1 = Yesterday

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

    private var formattedDateTitle: String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: selectedDateOffset, to: Date()) ?? Date()
        if selectedDateOffset == 0 {
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.dateFormat = "d MMM"
            return "Aujourd'hui \(df.string(from: date))"
        } else if selectedDateOffset == 1 {
            return "Demain"
        } else if selectedDateOffset == -1 {
            return "Hier"
        } else {
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.dateFormat = "EEE d MMM"
            return df.string(from: date).capitalized
        }
    }

    private var currentTimeString: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: Date())
    }

    public var body: some View {
        HStack(spacing: 0) {
            // ==========================================
            // COLUMN 1: CATEGORIES SIDEBAR (Width: 320)
            // ==========================================
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    // 1. FAVORITES CATEGORY
                    Button(action: {
                        appState.selectedCategory = "FAVORITES"
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            Text("Favorites")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            let favCount = appState.channelCount(for: "FAVORITES")
                            Text("\(favCount)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.yellow)
                                .cornerRadius(8)
                            if appState.selectedCategory == "FAVORITES" {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.card)

                    // 2. ALL CHANNELS
                    Button(action: {
                        appState.selectedCategory = "ALL"
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "tv")
                                .foregroundColor(.cyan)
                                .font(.system(size: 14))
                            Text("All Channels")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(appState.channelCount(for: "ALL"))")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.85))
                                .cornerRadius(8)
                            if appState.selectedCategory == "ALL" || appState.selectedCategory.isEmpty {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.card)

                    Divider().padding(.vertical, 4)

                    // 3. CATEGORIES LIST WITH CHANNEL COUNT BADGES
                    ForEach(appState.categories) { cat in
                        Button(action: {
                            appState.selectedCategory = cat.category_id
                        }) {
                            HStack(spacing: 8) {
                                Text(cat.category_name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                let count = appState.channelCount(for: cat.category_id)
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(cat.category_id == appState.selectedCategory ? Color.blue.opacity(0.3) : Color.white.opacity(0.08))
                                    .foregroundColor(cat.category_id == appState.selectedCategory ? .white : .secondary)
                                    .cornerRadius(8)
                                if cat.category_id == appState.selectedCategory {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.trailing, 8)
            }
            .frame(width: 320)

            Divider()

            // ==========================================
            // COLUMN 2: CHANNELS LIST (Width: 440)
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
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, ch in
                                EnhancedChannelRow(
                                    channel: ch,
                                    index: index + 1,
                                    isSelected: (activeChannel?.id == ch.id),
                                    onSelect: {
                                        selectedChannel = ch
                                    },
                                    onPlayFullscreen: {
                                        fullscreenChannel = ch
                                    },
                                    onShowInfo: {
                                        let items = buildScheduleItems(for: ch)
                                        selectedProgramForDetails = items.first(where: { $0.isLive }) ?? items.first
                                    }
                                )
                                .task {
                                    await appState.loadEpg(for: ch)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(width: 440)

            Divider()

            // ==========================================
            // COLUMN 3: LIVE PLAYER & HORIZONTAL EPG GRID
            // ==========================================
            VStack(alignment: .leading, spacing: 12) {
                if let ch = activeChannel {
                    // TOP: Embedded Live Player Preview (16:9 Aspect Ratio)
                    ZStack(alignment: .bottomTrailing) {
                        MiniPlayerView(streamUrl: ch.streamUrl)
                            .frame(height: 330)
                            .cornerRadius(14)
                            .clipped()
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                        // Fullscreen Button Overlay
                        Button(action: {
                            fullscreenChannel = ch
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12))
                                Text("Full Screen")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(14)
                    }

                    // BOTTOM: Horizontal EPG Guide Timeline
                    let scheduleItems = buildScheduleItems(for: ch)
                    let currentLive = scheduleItems.first(where: { $0.isLive }) ?? scheduleItems.first

                    VStack(alignment: .leading, spacing: 10) {
                        // 1. Channel Title & Subtitle + Toolbar Header
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.red).frame(width: 7, height: 7)
                                    Text(ch.title)
                                        .font(.system(size: 18, weight: .bold))
                                        .lineLimit(1)
                                }

                                Text(currentLive?.title ?? ch.categoryName ?? "Programme en cours")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Toolbar: Info, Layout, Search, Date Navigator
                            HStack(spacing: 8) {
                                Button(action: {
                                    selectedProgramForDetails = currentLive
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 15))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    fullscreenChannel = ch
                                }) {
                                    Image(systemName: "rectangle.grid.2x2")
                                        .font(.system(size: 14))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                // Date Navigator: < Aujourd'hui 25 nov. >
                                HStack(spacing: 6) {
                                    Button(action: {
                                        selectedDateOffset -= 1
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .buttonStyle(.plain)

                                    Text(formattedDateTitle)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 4)

                                    Button(action: {
                                        selectedDateOffset += 1
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                            }
                        }

                        // 2. Timeline Ruler Header (14:00, 16:00, 16:55 pin, 18:00, 20:00)
                        HStack(spacing: 0) {
                            Text("14:00")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("16:00")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            // Current Time Red Badge
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 5, height: 5)
                                Text(currentTimeString)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(6)
                            Spacer()
                            Text("18:00")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("20:00")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)

                        // 3. Horizontal Schedule Blocks (Matching Image 1)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(scheduleItems) { item in
                                    EpgTimelineCard(
                                        item: item,
                                        onSelect: {
                                            selectedProgramForDetails = item
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 155)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                } else {
                    Spacer()
                    Text("Select a channel to preview")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
        }
        .fullScreenCover(item: $fullscreenChannel) { channel in
            PlayerView(item: channel)
        }
        .sheet(item: $selectedProgramForDetails) { item in
            ProgramDetailModal(item: item, channelTitle: activeChannel?.title ?? "Channel")
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

    // MARK: - Schedule Items Builder
    private func buildScheduleItems(for channel: MediaItem) -> [EpgScheduleItem] {
        let cached = appState.epgCache[channel.id] ?? []
        if !cached.isEmpty {
            return cached.enumerated().map { index, p in
                let isLive = (index == 0) || (p.progress > 0.0 && p.progress < 1.0)
                let sTime = extractClock(p.start)
                let eTime = extractClock(p.end)
                let rawDuration = Int(((p.stopTimestamp ?? 0) - (p.startTimestamp ?? 0)) / 60)
                let duration = Swift.max(30, Swift.min(180, rawDuration))
                return EpgScheduleItem(
                    id: p.id,
                    title: p.title.isEmpty ? channel.title : p.title,
                    description: p.description,
                    startTime: sTime,
                    endTime: eTime,
                    timeRange: p.formattedTimeRange.isEmpty ? "\(sTime) - \(eTime)" : p.formattedTimeRange,
                    isLive: isLive,
                    progress: p.progress,
                    durationMinutes: duration > 0 ? duration : 45
                )
            }
        }

        // Fallback / Instant Realistic Grid
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let min = cal.component(.minute, from: now)

        let t0 = String(format: "%02d:%02d", max(0, hour - 1), 0)
        let t1 = String(format: "%02d:%02d", hour, 0)
        let t2 = String(format: "%02d:%02d", hour + 1, 0)
        let t3 = String(format: "%02d:%02d", hour + 2, 0)
        let t4 = String(format: "%02d:%02d", hour + 3, 0)

        let elapsedFraction = Double(min) / 60.0

        return [
            EpgScheduleItem(
                id: "\(channel.id)_past",
                title: "Émission précédente",
                description: "Programme diffusé plus tôt sur \(channel.title).",
                startTime: t0,
                endTime: t1,
                timeRange: "\(t0) - \(t1)",
                isLive: false,
                progress: 1.0,
                durationMinutes: 60
            ),
            EpgScheduleItem(
                id: "\(channel.id)_live",
                title: channel.title,
                description: "En direct sur \(channel.title). Retrouvez toute l'actualité et le divertissement.",
                startTime: t1,
                endTime: t2,
                timeRange: "\(t1) - \(t2)",
                isLive: true,
                progress: elapsedFraction,
                durationMinutes: 60
            ),
            EpgScheduleItem(
                id: "\(channel.id)_next1",
                title: "Grand Journal & Mag",
                description: "Le magazine de la rédaction et l'actualité en continu.",
                startTime: t2,
                endTime: t3,
                timeRange: "\(t2) - \(t3)",
                isLive: false,
                progress: 0.0,
                durationMinutes: 60
            ),
            EpgScheduleItem(
                id: "\(channel.id)_next2",
                title: "Soirée Prime Time",
                description: "Le grand divertissement du soir en haute définition.",
                startTime: t3,
                endTime: t4,
                timeRange: "\(t3) - \(t4)",
                isLive: false,
                progress: 0.0,
                durationMinutes: 60
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
        return raw.isEmpty ? "12:00" : raw
    }
}

// MARK: - EPG Schedule Item Model
public struct EpgScheduleItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let startTime: String
    public let endTime: String
    public let timeRange: String
    public let isLive: Bool
    public let progress: Double
    public let durationMinutes: Int
}

// MARK: - Enhanced Channel Row (Matching Image 1)
struct EnhancedChannelRow: View {
    @ObservedObject var appState = AppState.shared
    let channel: MediaItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlayFullscreen: () -> Void
    let onShowInfo: () -> Void

    var body: some View {
        Button(action: {
            if isSelected {
                onPlayFullscreen()
            } else {
                onSelect()
            }
        }) {
            HStack(spacing: 10) {
                // Channel Logo or Index Badge
                ZStack {
                    if let logo = channel.logoUrl, let url = URL(string: logo) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Text("\(index)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    } else {
                        Text("\(index)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                // Channel Name + Program Title + Progress Bar (Image 1 layout)
                let curProg = appState.epgCache[channel.id]?.first
                let progTitle = curProg?.title ?? channel.categoryName ?? "Live"
                let sTime = curProg?.start.split(separator: " ").dropFirst().first?.prefix(5) ?? "16:20"
                let eTime = curProg?.end.split(separator: " ").dropFirst().first?.prefix(5) ?? "17:00"
                let progress = curProg?.progress ?? 0.45

                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(progTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Real-Time Progress Bar with Start & End Time (16:20 [====] 17:01)
                    HStack(spacing: 6) {
                        Text("\(sTime)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)

                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.15))
                                Capsule().fill(Color(red: 0.25, green: 0.65, blue: 1.0))
                                    .frame(width: max(0, min(g.size.width, g.size.width * CGFloat(progress))))
                            }
                        }
                        .frame(height: 3)

                        Text("\(eTime)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Actions: Heart Favorite (♡ / ♥) and Info (ⓘ)
                HStack(spacing: 8) {
                    Button(action: {
                        appState.toggleFavorite(channel)
                    }) {
                        Image(systemName: appState.isFavorite(channel) ? "heart.fill" : "heart")
                            .foregroundColor(appState.isFavorite(channel) ? .red : .white.opacity(0.45))
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        onShowInfo()
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.45))
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(red: 0.1, green: 0.25, blue: 0.5).opacity(0.4) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(red: 0.25, green: 0.65, blue: 1.0) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.card)
        .onPlayPauseCommand {
            appState.toggleFavorite(channel)
        }
    }
}

// MARK: - Horizontal EPG Timeline Card (Matching Image 1)
struct EpgTimelineCard: View {
    let item: EpgScheduleItem
    let onSelect: () -> Void

    var cardWidth: CGFloat {
        let base = CGFloat(item.durationMinutes) * 3.2
        return max(150, min(320, base))
    }

    var body: some View {
        Button(action: {
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Header: Time Range & Live Tag
                HStack {
                    Text(item.timeRange)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(item.isLive ? Color(red: 0.35, green: 0.75, blue: 1.0) : .secondary)

                    Spacer()

                    if item.isLive {
                        HStack(spacing: 3) {
                            Circle().fill(Color.red).frame(width: 5, height: 5)
                            Text("En cours")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(4)
                    }
                }

                // Title
                Text(item.title)
                    .font(.system(size: 13, weight: item.isLive ? .bold : .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Subtitle / Snippet
                if !item.description.isEmpty && item.description != item.title {
                    Text(item.description)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }

                Spacer()

                // Progress Bar if Live
                if item.isLive {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(Color.blue)
                                .frame(width: max(0, min(g.size.width, g.size.width * CGFloat(item.progress))))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(10)
            .frame(width: cardWidth, height: 135)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.isLive ? Color(red: 0.12, green: 0.28, blue: 0.55).opacity(0.4) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.isLive ? Color(red: 0.3, green: 0.65, blue: 1.0) : Color.white.opacity(0.1), lineWidth: item.isLive ? 1.5 : 1)
            )
        }
        .buttonStyle(.card)
    }
}

// MARK: - Program Detail Modal
struct ProgramDetailModal: View {
    let item: EpgScheduleItem
    let channelTitle: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(channelTitle)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    Text(item.title)
                        .font(.title2)
                        .fontWeight(.heavy)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                Label(item.timeRange, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if item.isLive {
                    Text("• DIFFUSION EN DIRECT")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.red)
                }
            }

            Divider()

            ScrollView {
                Text(item.description.isEmpty ? "Aucune description détaillée fournie pour ce programme." : item.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 700, maxHeight: 460)
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
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
