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
            // CATEGORIES SIDEBAR
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
                                Text(cat.category_name)
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
                .padding(.trailing, 20)
            }
            .frame(width: 380)

            Divider()

            // SERIES GRID
            if appState.isLoadingSeries {
                VStack {
                    Spacer()
                    ProgressView("Loading TV series…")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredSeries.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "play.tv")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No series available in this category.")
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 25)], spacing: 30) {
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
                                                Color.gray.opacity(0.3)
                                                    .overlay(Image(systemName: "play.tv").font(.largeTitle))
                                            }
                                        }
                                        .frame(width: 220, height: 330)
                                        .cornerRadius(12)
                                        .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 220, height: 330)
                                            .cornerRadius(12)
                                            .overlay(Image(systemName: "play.tv").font(.largeTitle))
                                    }

                                    Text(series.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .frame(width: 220, alignment: .leading)
                                }
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedSeries) { series in
            SeriesDetailView(series: series)
        }
        .task {
            if appState.seriesList.isEmpty && appState.activePlaylistId != nil {
                await appState.loadSeriesForActivePlaylist()
            }
        }
    }
}

public struct SeriesDetailView: View {
    public let series: SeriesItem
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    @State private var episodes: [EpisodeItem] = []
    @State private var selectedSeason: Int = 1
    @State private var isLoadingEpisodes: Bool = true
    @State private var playingEpisode: MediaItem?

    public var availableSeasons: [Int] {
        Array(Set(episodes.map { $0.seasonNum })).sorted()
    }

    public var seasonEpisodes: [EpisodeItem] {
        episodes.filter { $0.seasonNum == selectedSeason }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 30) {
                if let cover = series.coverUrl, let url = URL(string: cover) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 180, height: 270)
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(series.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            let media = MediaItem(id: "\(series.seriesId)", title: series.title, kind: .series, streamUrl: "", logoUrl: series.coverUrl)
                            appState.toggleFavorite(media)
                        }) {
                            let media = MediaItem(id: "\(series.seriesId)", title: series.title, kind: .series, streamUrl: "", logoUrl: series.coverUrl)
                            Image(systemName: appState.isFavorite(media) ? "heart.fill" : "heart")
                                .foregroundColor(appState.isFavorite(media) ? .red : .white)
                                .font(.headline)
                        }
                        .buttonStyle(.plain)

                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }

                    if let rating = series.rating, !rating.isEmpty, rating != "0" {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                            Text(rating)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.yellow)
                        .cornerRadius(6)
                    }

                    if let plot = series.plot, !plot.isEmpty {
                        Text(plot)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                }
                Spacer()
            }
            .frame(height: 270)

            // SEASONS PICKER
            if !availableSeasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableSeasons, id: \.self) { s in
                            Button("Season \(s)") {
                                selectedSeason = s
                            }
                            .buttonStyle(.bordered)
                            .background(selectedSeason == s ? Color.blue.opacity(0.4) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // EPISODES LIST
            if isLoadingEpisodes {
                ProgressView("Loading episodes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if seasonEpisodes.isEmpty {
                Text("No episodes found for this season.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 10) {
                        ForEach(seasonEpisodes) { ep in
                            Button(action: {
                                let item = MediaItem(
                                    id: "\(ep.episodeId)",
                                    title: "\(series.title) - S\(ep.seasonNum)E\(ep.episodeNum): \(ep.title)",
                                    kind: .episode,
                                    streamUrl: ep.streamUrl,
                                    logoUrl: ep.coverUrl ?? series.coverUrl
                                )
                                appState.addToHistory(item)
                                playingEpisode = item
                            }) {
                                HStack {
                                    Text("E\(ep.episodeNum)")
                                        .fontWeight(.bold)
                                        .frame(width: 50, alignment: .leading)
                                    Text(ep.title)
                                    Spacer()
                                    Image(systemName: "play.fill")
                                }
                                .padding()
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
        }
        .padding(40)
        .task {
            guard let active = appState.playlists.first(where: { $0.id == appState.activePlaylistId }) else { return }
            let (user, pass) = XtreamService.extractCredentials(from: active.url, user: active.username, pass: active.password)
            guard !user.isEmpty && !pass.isEmpty else { return }
            do {
                let eps = try await XtreamService.fetchSeriesEpisodes(serverUrl: active.url, user: user, pass: pass, seriesId: series.seriesId)
                self.episodes = eps
                if let firstSeason = eps.first?.seasonNum {
                    self.selectedSeason = firstSeason
                }
            } catch {
                print("Error loading series episodes: \(error)")
            }
            self.isLoadingEpisodes = false
        }
        .fullScreenCover(item: $playingEpisode) { ep in
            PlayerView(item: ep)
        }
    }
}
