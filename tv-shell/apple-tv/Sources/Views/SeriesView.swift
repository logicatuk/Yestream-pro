import SwiftUI

public struct SeriesView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedSeries: SeriesItem?

    public var filteredSeries: [SeriesItem] {
        if appState.selectedSeriesCategory.isEmpty || appState.selectedSeriesCategory == "ALL" {
            return appState.seriesList
        }
        return appState.seriesList.filter { $0.categoryId == appState.selectedSeriesCategory }
    }

    public var body: some View {
        HStack(spacing: 0) {
            // ==========================================
            // CATEGORIES SIDEBAR
            // ==========================================
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    // ALL SERIES
                    Button(action: {
                        appState.selectedSeriesCategory = "ALL"
                    }) {
                        HStack {
                            Text("All Series")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            if !appState.seriesList.isEmpty {
                                Text("\(appState.seriesList.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if appState.selectedSeriesCategory == "ALL" || appState.selectedSeriesCategory.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    ForEach(appState.seriesCategories) { cat in
                        Button(action: {
                            appState.selectedSeriesCategory = cat.category_id
                        }) {
                            HStack {
                                Text(cat.category_name.cleanedIptvTitle)
                                    .lineLimit(1)
                                Spacer()
                                if cat.category_id == appState.selectedSeriesCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .frame(width: 340)
            .background(Color(red: 0.04, green: 0.06, blue: 0.11))

            Divider().background(Color.white.opacity(0.08))

            // ==========================================
            // SERIES GRID
            // ==========================================
            if appState.isLoadingSeries {
                VStack {
                    Spacer()
                    ProgressView("Loading TV series…")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.035, green: 0.05, blue: 0.09))
            } else if filteredSeries.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "play.tv")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No series available in this category.")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.035, green: 0.05, blue: 0.09))
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 230), spacing: 24)], spacing: 28) {
                        ForEach(filteredSeries) { series in
                            Button(action: {
                                selectedSeries = series
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let cover = series.coverUrl, let url = URL(string: cover) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                Color.gray.opacity(0.25)
                                                    .overlay(Image(systemName: "play.tv").font(.largeTitle))
                                            }
                                        }
                                        .frame(width: 210, height: 310)
                                        .cornerRadius(14)
                                        .clipped()
                                    } else {
                                        Color.gray.opacity(0.25)
                                            .frame(width: 210, height: 310)
                                            .cornerRadius(14)
                                            .overlay(Image(systemName: "play.tv").font(.largeTitle))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(series.title.cleanedIptvTitle)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        HStack {
                                            if let r = series.rating, !r.isEmpty, r != "0" {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 10))
                                                    Text(r).font(.system(size: 11, weight: .bold))
                                                }
                                                .foregroundColor(.yellow)
                                            }

                                            Spacer()

                                            Text("Series")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .frame(width: 210)
                                }
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(24)
                }
                .background(Color(red: 0.035, green: 0.05, blue: 0.09))
            }
        }
        .fullScreenCover(item: $selectedSeries) { series in
            SeriesDetailView(series: series)
        }
        .task {
            if appState.seriesList.isEmpty && appState.activePlaylistId != nil {
                await appState.loadSeriesForActivePlaylist()
            }
        }
    }
}

// MARK: - Cinematic Series Detail View (Backdrop, TMDB info, Seasons & SubDL Subtitles)
public struct SeriesDetailView: View {
    public let series: SeriesItem
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    enum SeriesDetailFocus: Hashable {
        case back
        case favorite
        case playNext
        case subtitles
    }

    @FocusState private var focusedField: SeriesDetailFocus?
    @State private var detail: SeriesDetail?
    @State private var isLoading: Bool = true
    @State private var selectedSeason: Int = 1
    @State private var playingEpisode: MediaItem?

    // SubDL Subtitles State
    @State private var showSubtitles: Bool = false
    @State private var subtitles: [SubDLSubtitleItem] = []
    @State private var isSearchingSubs: Bool = false

    public var availableSeasons: [Int] {
        let eps = detail?.episodes ?? []
        let seasons = Set(eps.map { $0.seasonNum })
        return Array(seasons).sorted()
    }

    public var currentSeasonEpisodes: [EpisodeItem] {
        let eps = detail?.episodes ?? []
        return eps.filter { $0.seasonNum == selectedSeason }
    }

    private var firstPlayableEpisode: EpisodeItem? {
        currentSeasonEpisodes.first ?? detail?.episodes.first
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.035, green: 0.05, blue: 0.09).ignoresSafeArea()

            // 1. CINEMATIC BACKDROP BANNER
            if let backdrop = detail?.backdropUrl ?? series.coverUrl, let url = URL(string: backdrop) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.78),
                            Color(red: 0.035, green: 0.05, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            }

            // 2. MAIN SCROLLABLE CONTENT
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .focused($focusedField, equals: .back)

                        Spacer()

                        let asMedia = MediaItem(
                            id: "series_\(series.seriesId)",
                            title: series.title,
                            kind: .series,
                            streamUrl: "",
                            logoUrl: series.coverUrl,
                            rating: series.rating,
                            plot: series.plot
                        )

                        Button(action: {
                            appState.toggleFavorite(asMedia)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: appState.isFavorite(asMedia) ? "heart.fill" : "heart")
                                Text(appState.isFavorite(asMedia) ? "Favorited" : "Add to Favorites")
                            }
                            .font(.headline)
                            .foregroundColor(appState.isFavorite(asMedia) ? .red : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .focused($focusedField, equals: .favorite)
                    }
                    .padding(.top, 12)
                    .focusSection()

                    // Hero Content
                    HStack(alignment: .top, spacing: 36) {
                        // Poster
                        if let poster = detail?.posterUrl ?? series.coverUrl, let url = URL(string: poster) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFit()
                                } else {
                                    Color.gray.opacity(0.25)
                                        .overlay(Image(systemName: "play.tv").font(.largeTitle))
                                }
                            }
                            .frame(width: 240, height: 360)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.8), radius: 18, y: 8)
                        }

                        // Info Column
                        VStack(alignment: .leading, spacing: 14) {
                            Text(detail?.name ?? series.title.cleanedIptvTitle)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            // Metadata Badges Row
                            HStack(spacing: 12) {
                                if let rating = detail?.rating ?? series.rating, !rating.isEmpty, rating != "0" {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill").foregroundColor(.yellow)
                                        Text(rating)
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(6)
                                }

                                if let date = detail?.releaseDate, !date.isEmpty {
                                    Text(date.prefix(4))
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(6)
                                }

                                if !availableSeasons.isEmpty {
                                    Text("\(availableSeasons.count) Seasons")
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(6)
                                }

                                if let genre = detail?.genre, !genre.isEmpty {
                                    Text(genre)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }

                            // Action Buttons
                            HStack(spacing: 16) {
                                if let ep = firstPlayableEpisode {
                                    Button(action: {
                                        playEpisode(ep)
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "play.fill")
                                            Text("Watch S\(ep.seasonNum) E\(ep.episodeNum)")
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 22)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .focused($focusedField, equals: .playNext)
                                }

                                Button(action: {
                                    showSubtitles.toggle()
                                    if showSubtitles && subtitles.isEmpty {
                                        Task {
                                            await searchSubtitles()
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "captions.bubble.fill")
                                        Text("Subtitles (SubDL)")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)
                                .focused($focusedField, equals: .subtitles)
                            }
                            .padding(.vertical, 4)

                            // Plot / Synopsis
                            if let plot = detail?.plot ?? series.plot, !plot.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Synopsis")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(plot)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(4)
                                        .lineLimit(4)
                                }
                            }

                            // Cast
                            if let cast = detail?.cast, !cast.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("Cast:")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                    Text(cast)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .focusSection()

                    // SUBDL SUBTITLES DRAWER
                    if showSubtitles {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "captions.bubble.fill")
                                    .foregroundColor(.cyan)
                                Text("Available Subtitles (SubDL Engine)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                if isSearchingSubs {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }

                            if subtitles.isEmpty && !isSearchingSubs {
                                Text("No external subtitles found for this series on SubDL.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(subtitles) { sub in
                                            Button(action: {
                                                if let ep = firstPlayableEpisode {
                                                    playEpisode(ep)
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text(sub.language.uppercased())
                                                            .font(.caption2)
                                                            .fontWeight(.black)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.cyan.opacity(0.25))
                                                            .foregroundColor(.cyan)
                                                            .cornerRadius(4)
                                                        if sub.hearingImpaired {
                                                            Text("CC")
                                                                .font(.caption2)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                    Text(sub.releaseName)
                                                        .font(.caption)
                                                        .lineLimit(2)
                                                        .foregroundColor(.white)
                                                    Text("Ready to stream")
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                }
                                                .padding(12)
                                                .frame(width: 200, height: 95)
                                                .background(Color.white.opacity(0.08))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .focusSection()
                    }

                    // 3. SEASONS SELECTOR TABS
                    if !availableSeasons.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SEASONS")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(availableSeasons, id: \.self) { s in
                                        Button(action: {
                                            selectedSeason = s
                                        }) {
                                            Text("Season \(s)")
                                        }
                                        .buttonStyle(SeasonTabButtonStyle(isSelected: selectedSeason == s))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        .focusSection()
                    }

                    // 4. EPISODES GRID
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("EPISODES (SEASON \(selectedSeason))")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(currentSeasonEpisodes.count) Episodes")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if isLoading {
                            ProgressView("Loading episodes…")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else if currentSeasonEpisodes.isEmpty {
                            Text("No episodes available for this season.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 400), spacing: 20)], spacing: 20) {
                                ForEach(currentSeasonEpisodes) { ep in
                                    Button(action: {
                                        playEpisode(ep)
                                    }) {
                                        HStack(spacing: 14) {
                                            // Episode Thumbnail / Cover
                                            ZStack {
                                                if let cover = ep.coverUrl ?? detail?.backdropUrl ?? series.coverUrl, let url = URL(string: cover) {
                                                    AsyncImage(url: url) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().scaledToFill()
                                                        } else {
                                                            Color.white.opacity(0.08)
                                                        }
                                                    }
                                                } else {
                                                    Color.white.opacity(0.08)
                                                }

                                                // Play icon overlay
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Image(systemName: "play.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                    )

                                                // Season/Episode Badge
                                                VStack {
                                                    HStack {
                                                        Text("E\(ep.episodeNum)")
                                                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.black.opacity(0.75))
                                                            .foregroundColor(.white)
                                                            .cornerRadius(4)
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                .padding(6)
                                            }
                                            .frame(width: 140, height: 88)
                                            .cornerRadius(10)
                                            .clipped()

                                            // Episode Info
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(ep.title.cleanedIptvTitle)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(2)

                                                if let dur = ep.duration, !dur.isEmpty {
                                                    Text(dur)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundColor(.white.opacity(0.6))
                                                }

                                                if let plot = ep.plot, !plot.isEmpty {
                                                    Text(plot)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.white.opacity(0.65))
                                                        .lineLimit(2)
                                                }

                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(10)
                                        .frame(height: 108)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    }
                    .focusSection()
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 60)
            }
        }
        .task {
            await loadDetails()
        }
        .fullScreenCover(item: $playingEpisode) { ep in
            PlayerView(item: ep)
        }
    }

    private func playEpisode(_ ep: EpisodeItem) {
        let media = MediaItem(
            id: "ep_\(ep.episodeId)",
            title: "\(series.title.cleanedIptvTitle) - S\(ep.seasonNum) E\(ep.episodeNum): \(ep.title.cleanedIptvTitle)",
            kind: .episode,
            streamUrl: ep.streamUrl,
            logoUrl: ep.coverUrl ?? series.coverUrl,
            plot: ep.plot
        )
        appState.addToHistory(media)
        self.playingEpisode = media
    }

    private func loadDetails() async {
        guard let active = appState.playlists.first(where: { $0.id == appState.activePlaylistId }) else { return }
        let (u, p) = XtreamService.extractCredentials(from: active.url, user: active.username, pass: active.password)
        guard !u.isEmpty && !p.isEmpty else { return }

        if let det = await XtreamService.fetchSeriesDetails(serverUrl: active.url, user: u, pass: p, seriesId: series.seriesId) {
            self.detail = det
            if let firstSeason = det.episodes.first?.seasonNum {
                self.selectedSeason = firstSeason
            }
        }
        self.isLoading = false
    }

    private func searchSubtitles() async {
        isSearchingSubs = true
        let subs = await SubDLService.searchSeriesSubtitles(
            title: series.title.cleanedIptvTitle,
            season: selectedSeason,
            episode: firstPlayableEpisode?.episodeNum ?? 1
        )
        self.subtitles = subs
        self.isSearchingSubs = false
    }
}

// MARK: - Season Tab Button Style (Precision tvOS Focus & Selection)
public struct SeasonTabButtonStyle: ButtonStyle {
    public let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        SeasonTabButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct SeasonTabButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
            configuration.label
                .font(.system(size: 15, weight: (isSelected || isFocused) ? .bold : .medium))
        }
        .foregroundColor(isFocused ? .black : (isSelected ? .white : Color.white.opacity(0.75)))
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isFocused ? Color.white : (isSelected ? Color(red: 0.12, green: 0.44, blue: 0.96) : Color.white.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.white : (isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.12)),
                    lineWidth: 1.5
                )
        )
        .scaleEffect(isFocused ? 1.06 : (configuration.isPressed ? 0.95 : 1.0))
        .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

