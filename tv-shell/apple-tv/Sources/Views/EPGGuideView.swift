import SwiftUI

// MARK: - EPG Guide View (Grid Timeline matching Web App Layout)
public struct EPGGuideView: View {
    @ObservedObject var appState = AppState.shared

    // Filter & Navigation States
    @State private var selectedCategoryId: String = "ALL"
    @State private var showCategoryPicker: Bool = false
    @State private var onlyWithEpg: Bool = true // Default to true: only show channels that have EPG
    @State private var channelQuery: String = ""
    @State private var selectedDateOffset: Int = 0 // 0 = Today, 1 = Tomorrow
    @State private var selectedProgram: EpgProgram?
    @State private var selectedChannelForDetails: MediaItem?
    @State private var playingChannel: MediaItem?

    // Timeline Configuration
    private let hourWidth: CGFloat = 260.0 // 1 hour = 260pt (30 min = 130pt)
    private let channelColumnWidth: CGFloat = 340.0
    private let rowHeight: CGFloat = 68.0

    // Current Time Line
    @State private var currentTime: Date = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    public init() {}

    // Filtered Channels (ALL channels, no artificial 40 limit)
    private var filteredChannels: [MediaItem] {
        var list = appState.channels

        if selectedCategoryId != "ALL" && !selectedCategoryId.isEmpty {
            list = list.filter { $0.categoryId == selectedCategoryId }
        }

        if !channelQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(channelQuery) }
        }

        if onlyWithEpg {
            list = list.filter { ch in
                let progs = appState.epgCache[ch.id] ?? []
                return !progs.isEmpty || ch.hasEpg
            }
        }

        return list
    }

    // Time Slots for Ruler (24 Hours of Half-Hour Slots: 00:00, 00:30, 01:00...)
    private var timeSlots: [Date] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: selectedDateOffset, to: Date()) ?? Date())
        return (0..<48).compactMap { halfHour in
            calendar.date(byAdding: .minute, value: halfHour * 30, to: startOfDay)
        }
    }

    // Current Minute Offset from 00:00 in Points
    private var nowOffsetPoints: CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let elapsedMinutes = currentTime.timeIntervalSince(startOfDay) / 60.0
        guard elapsedMinutes >= 0 && elapsedMinutes <= 1440 else { return -1 }
        return CGFloat(elapsedMinutes / 60.0) * hourWidth
    }

    private var nowTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateLabel: String {
        if selectedDateOffset == 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, d MMM"
            return "\(formatter.string(from: Date())) Today"
        } else if selectedDateOffset == 1 {
            return "Tomorrow"
        } else if selectedDateOffset == -1 {
            return "Yesterday"
        }
        return "Day \(selectedDateOffset)"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ==========================================
            // 1. TOP CONTROL TOOLBAR (Web App Style)
            // ==========================================
            topToolbar
                .frame(height: 56)

            Divider().background(Color.white.opacity(0.12))

            // ==========================================
            // 2. TIMELINE GRID: Pinned Channel Column + Scrollable Timeline
            // ==========================================
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    // Pinned Left Channel Column
                    VStack(alignment: .leading, spacing: 0) {
                        // Sticky Header Label: CHANNEL
                        HStack {
                            Text("CHANNEL")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(filteredChannels.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .frame(width: channelColumnWidth, height: 38)
                        .background(Color(red: 0.05, green: 0.07, blue: 0.12))

                        Divider().background(Color.white.opacity(0.08))

                        // Channel Rows (LazyVStack for all channels)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, channel in
                                let isEven = index % 2 == 0
                                EpgChannelRowTile(
                                    index: index + 1,
                                    channel: channel,
                                    isPlaying: channel.id == appState.currentlyPlaying?.id,
                                    rowWidth: channelColumnWidth,
                                    rowHeight: rowHeight,
                                    backgroundColor: isEven ? Color(red: 0.05, green: 0.07, blue: 0.12) : Color(red: 0.07, green: 0.10, blue: 0.16),
                                    onPlay: {
                                        playChannel(channel)
                                    }
                                )
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .frame(width: channelColumnWidth)
                    .background(Color(red: 0.06, green: 0.08, blue: 0.14))

                    Divider().background(Color.white.opacity(0.12))

                    // Horizontally Scrollable Timeline Rails
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Timeline Ruler
                            timelineHeaderRuler
                                .frame(height: 38)

                            Divider().background(Color.white.opacity(0.08))

                            // Programme Rails with Vertical Red NOW Line
                            ZStack(alignment: .topLeading) {
                                // Vertical NOW Pink/Red Line
                                if selectedDateOffset == 0 && nowOffsetPoints >= 0 {
                                    Rectangle()
                                        .fill(Color(red: 0.95, green: 0.35, blue: 0.45))
                                        .frame(width: 2, height: CGFloat(max(filteredChannels.count, 1)) * (rowHeight + 1))
                                        .offset(x: nowOffsetPoints)
                                        .zIndex(10)
                                        .allowsHitTesting(false)
                                }

                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, channel in
                                        let isEven = index % 2 == 0
                                        programmeRail(for: channel, isEven: isEven)
                                            .frame(height: rowHeight)
                                        Divider().background(Color.white.opacity(0.06))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 3. BOTTOM INSPECTOR & SHORTCUTS BAR
            // ==========================================
            bottomInspectorBar
                .frame(height: 48)
        }
        .background(Color(red: 0.04, green: 0.06, blue: 0.11).edgesIgnoringSafeArea(.all))
        .onReceive(timer) { date in
            currentTime = date
        }
        .fullScreenCover(item: $playingChannel) { ch in
            PlayerView(item: ch)
        }
        .sheet(isPresented: $showCategoryPicker) {
            categoryPickerSheet
        }
        .task {
            await prefetchEpg()
        }
        .onChange(of: selectedCategoryId) { _ in
            Task {
                await prefetchEpg()
            }
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 14) {
            // Date Navigator
            HStack(spacing: 6) {
                EpgToolbarButton(icon: "chevron.left") {
                    if selectedDateOffset > -1 { selectedDateOffset -= 1 }
                }

                Text(dateLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 120, alignment: .center)

                EpgToolbarButton(icon: "chevron.right") {
                    if selectedDateOffset < 2 { selectedDateOffset += 1 }
                }
            }

            // NOW Button
            EpgToolbarButton(title: "Now", circleColor: .red) {
                selectedDateOffset = 0
                currentTime = Date()
            }

            // Category Selector
            EpgToolbarButton(title: categoryName(for: selectedCategoryId), iconRight: "chevron.down") {
                showCategoryPicker = true
            }

            // Only With EPG Toggle
            EpgToolbarButton(
                title: "Only with EPG",
                icon: onlyWithEpg ? "checkmark.circle.fill" : "circle",
                iconColor: onlyWithEpg ? Color.cyan : Color.secondary,
                isActive: onlyWithEpg
            ) {
                onlyWithEpg.toggle()
            }

            Spacer()

            // Custom Sleek Search Field (No White Bulb!)
            EpgSearchField(text: $channelQuery)
        }
        .padding(.horizontal, 40)
        .background(Color(red: 0.06, green: 0.09, blue: 0.16))
    }

    // MARK: - Timeline Header Ruler
    private var timelineHeaderRuler: some View {
        HStack(spacing: 0) {
            ForEach(timeSlots, id: \.self) { slot in
                Text(formatSlotTime(slot))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: hourWidth / 2, alignment: .leading)
            }
        }
        .frame(height: 38)
        .background(Color(red: 0.05, green: 0.07, blue: 0.12))
        .overlay(
            Group {
                if selectedDateOffset == 0 && nowOffsetPoints >= 0 {
                    Text(nowTimeLabel)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.35, blue: 0.45))
                        .cornerRadius(6)
                        .offset(x: nowOffsetPoints - 24)
                }
            },
            alignment: .leading
        )
    }

    // MARK: - Right Programme Rail
    private func programmeRail(for channel: MediaItem, isEven: Bool) -> some View {
        let progs = appState.epgCache[channel.id] ?? []
        let rowBg = isEven ? Color(red: 0.05, green: 0.07, blue: 0.12) : Color(red: 0.07, green: 0.09, blue: 0.15)

        return HStack(spacing: 6) {
            if progs.isEmpty {
                EpgEmptyRailTile(
                    channel: channel,
                    rowHeight: rowHeight,
                    onPlay: {
                        playChannel(channel)
                    }
                )
                .task {
                    await appState.loadEpg(for: channel)
                }
            } else {
                ForEach(progs) { prog in
                    EpgProgrammeBlockTile(
                        program: prog,
                        width: calculateProgWidth(prog),
                        rowHeight: rowHeight,
                        onSelect: {
                            selectedProgram = prog
                            selectedChannelForDetails = channel
                            playChannel(channel)
                        }
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(minWidth: hourWidth * 24, alignment: .leading)
        .background(rowBg)
    }

    // MARK: - Bottom Inspector
    private var bottomInspectorBar: some View {
        HStack(spacing: 24) {
            if let p = selectedProgram, let ch = selectedChannelForDetails {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(ch.title.cleanedIptvTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(p.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("(\(p.formattedTimeRange))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    if !p.description.isEmpty {
                        Text(p.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Select any channel or show to inspect details and start playback.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            HStack(spacing: 16) {
                legendItem(keys: "↑ ↓", action: "channel")
                legendItem(keys: "← →", action: "programme")
                legendItem(keys: "Enter", action: "play")
                legendItem(keys: "●", action: "now")
            }
        }
        .padding(.horizontal, 40)
        .background(Color(red: 0.05, green: 0.07, blue: 0.13))
        .overlay(
            Divider().background(Color.white.opacity(0.12)),
            alignment: .top
        )
    }

    private func legendItem(keys: String, action: String) -> some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .cornerRadius(4)
                .foregroundColor(.white)
            Text(action)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
        }
    }

    // MARK: - Category Picker Sheet
    private var categoryPickerSheet: some View {
        VStack(spacing: 20) {
            Text("Select Category")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    Button(action: {
                        selectedCategoryId = "ALL"
                        showCategoryPicker = false
                    }) {
                        HStack {
                            Text("All Categories")
                                .fontWeight(.bold)
                            Spacer()
                            if selectedCategoryId == "ALL" {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    ForEach(appState.categories) { cat in
                        Button(action: {
                            selectedCategoryId = cat.category_id
                            showCategoryPicker = false
                        }) {
                            HStack {
                                Text(cat.category_name)
                                Spacer()
                                if selectedCategoryId == cat.category_id {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding()
            }

            Button("Done") {
                showCategoryPicker = false
            }
            .buttonStyle(.bordered)
        }
        .padding(30)
        .frame(width: 560, height: 700)
    }

    // MARK: - Helpers
    private func playChannel(_ channel: MediaItem) {
        appState.addToHistory(channel)
        playingChannel = channel
    }

    private func calculateProgWidth(_ prog: EpgProgram) -> CGFloat {
        guard let s = prog.startTimestamp, let e = prog.stopTimestamp, e > s else {
            return 180.0
        }
        let durationHours = (e - s) / 3600.0
        let w = CGFloat(durationHours) * hourWidth
        return max(w, 100.0)
    }

    private func formatSlotTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func categoryName(for id: String) -> String {
        if id == "ALL" { return "All Categories" }
        return appState.categories.first(where: { $0.category_id == id })?.category_name ?? "Category"
    }

    private func prefetchEpg() async {
        let baseList: [MediaItem]
        if selectedCategoryId != "ALL" && !selectedCategoryId.isEmpty {
            baseList = appState.channels.filter { $0.categoryId == selectedCategoryId }
        } else {
            // Prioritize broadcast channels with potential EPG (non-ambient)
            let broadcast = appState.channels.filter { ch in
                let cat = ch.categoryName?.lowercased() ?? ""
                return !cat.contains("relax")
            }
            baseList = broadcast.isEmpty ? appState.channels : broadcast
        }

        let candidates = Array(baseList.prefix(80))
        await withTaskGroup(of: Void.self) { group in
            for ch in candidates {
                if appState.epgCache[ch.id] == nil {
                    group.addTask {
                        await appState.loadEpg(for: ch)
                    }
                }
            }
        }
    }
}

// MARK: - Custom Sleek Focusable Channel Row Tile (No White Blob!)
private struct EpgChannelRowTile: View {
    let index: Int
    let channel: MediaItem
    let isPlaying: Bool
    let rowWidth: CGFloat
    let rowHeight: CGFloat
    let backgroundColor: Color
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, alignment: .trailing)

                if let logo = channel.logoUrl, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.35))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.35))
                        .overlay(
                            Image(systemName: "tv")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.title.cleanedIptvTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if isPlaying {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text("Playing")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                    } else if let cat = channel.categoryName, !cat.isEmpty {
                        Text(cat)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        Text("No programme information")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(width: rowWidth - 12, height: rowHeight - 6, alignment: .leading)
        }
        .buttonStyle(EpgChannelButtonStyle(backgroundColor: backgroundColor))
        .padding(.horizontal, 6)
    }
}

// MARK: - EpgChannelButtonStyle
private struct EpgChannelButtonStyle: ButtonStyle {
    let backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        EpgChannelButtonBody(configuration: configuration, backgroundColor: backgroundColor)
    }
}

private struct EpgChannelButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let backgroundColor: Color
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color(red: 0.14, green: 0.28, blue: 0.54) : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.cyan : Color.white.opacity(0.04), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: isFocused ? Color.cyan.opacity(0.4) : Color.clear, radius: 5)
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Custom Sleek Focusable Programme Block Tile (No White Blob!)
private struct EpgProgrammeBlockTile: View {
    let program: EpgProgram
    let width: CGFloat
    let rowHeight: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 3) {
                Text(program.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(program.formattedTimeRange)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.85, green: 0.92, blue: 1.0))

                if program.progress > 0 && program.progress < 1.0 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2))
                            Capsule().fill(Color(red: 0.2, green: 0.85, blue: 1.0))
                                .frame(width: g.size.width * CGFloat(program.progress))
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: width, height: rowHeight - 8, alignment: .leading)
        }
        .buttonStyle(EpgProgrammeButtonStyle(width: width, rowHeight: rowHeight))
    }
}

// MARK: - EpgProgrammeButtonStyle
private struct EpgProgrammeButtonStyle: ButtonStyle {
    let width: CGFloat
    let rowHeight: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        EpgProgrammeButtonBody(configuration: configuration, width: width, rowHeight: rowHeight)
    }
}

private struct EpgProgrammeButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let width: CGFloat
    let rowHeight: CGFloat
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color(red: 0.14, green: 0.30, blue: 0.58) : Color(red: 0.10, green: 0.14, blue: 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.cyan : Color.white.opacity(0.08), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: isFocused ? Color.cyan.opacity(0.4) : Color.clear, radius: 6)
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Focusable Empty Programme Rail Tile (No White Blob!)
private struct EpgEmptyRailTile: View {
    let channel: MediaItem
    let rowHeight: CGFloat
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                Text("No programme information for this channel")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 16)
                Spacer()
            }
            .frame(width: 800, height: rowHeight - 8, alignment: .leading)
        }
        .buttonStyle(EpgEmptyRailButtonStyle())
    }
}

private struct EpgEmptyRailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EpgEmptyRailButtonBody(configuration: configuration)
    }
}

private struct EpgEmptyRailButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color.white.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.white.opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Custom Sleek Focusable Toolbar Button (No White Pill!)
private struct EpgToolbarButton: View {
    var title: String? = nil
    var icon: String? = nil
    var iconRight: String? = nil
    var circleColor: Color? = nil
    var iconColor: Color? = nil
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let circle = circleColor {
                    Circle().fill(circle).frame(width: 8, height: 8)
                }
                if let ic = icon {
                    Image(systemName: ic)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor ?? .white)
                }
                if let t = title {
                    Text(t)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                if let icR = iconRight {
                    Image(systemName: icR)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(EpgToolbarButtonStyle(isActive: isActive))
    }
}

private struct EpgToolbarButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        EpgToolbarButtonBody(configuration: configuration, isActive: isActive)
    }
}

private struct EpgToolbarButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isActive: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color(red: 0.14, green: 0.28, blue: 0.54) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.cyan : (isActive ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12)), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: isFocused ? Color.cyan.opacity(0.35) : Color.clear, radius: 4)
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Custom Sleek Focusable Search Field (No White Bulb!)
private struct EpgSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isFocused ? .cyan : .secondary)

            TextField("Filter channels…", text: $text)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 220, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Color(red: 0.12, green: 0.20, blue: 0.38) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.cyan : Color.white.opacity(0.12), lineWidth: isFocused ? 2 : 1)
        )
        .shadow(color: isFocused ? Color.cyan.opacity(0.35) : Color.clear, radius: 5)
    }
}
