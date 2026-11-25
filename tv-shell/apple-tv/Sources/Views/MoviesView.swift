import SwiftUI

public struct MoviesView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedMovie: MediaItem?

    public var filteredMovies: [MediaItem] {
        if appState.selectedVodCategory.isEmpty || appState.selectedVodCategory == "ALL" {
            return appState.vodMovies
        }
        return appState.vodMovies.filter { $0.categoryId == appState.selectedVodCategory }
    }

    public var body: some View {
        HStack(spacing: 0) {
            // CATEGORIES SIDEBAR
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    // ALL MOVIES
                    Button(action: {
                        appState.selectedVodCategory = "ALL"
                    }) {
                        HStack {
                            Text("All Movies")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            if !appState.vodMovies.isEmpty {
                                Text("\(appState.vodMovies.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if appState.selectedVodCategory == "ALL" || appState.selectedVodCategory.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    ForEach(appState.vodCategories) { cat in
                        Button(action: {
                            appState.selectedVodCategory = cat.category_id
                        }) {
                            HStack {
                                Text(cat.category_name)
                                    .lineLimit(1)
                                Spacer()
                                if cat.category_id == appState.selectedVodCategory {
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

            // MOVIES GRID
            if appState.isLoadingVod {
                VStack {
                    Spacer()
                    ProgressView("Loading movie catalog…")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredMovies.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No movies available in this category.")
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 25)], spacing: 30) {
                        ForEach(filteredMovies) { movie in
                            Button(action: {
                                selectedMovie = movie
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let logo = movie.logoUrl, let url = URL(string: logo) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                Color.gray.opacity(0.3)
                                                    .overlay(Image(systemName: "film").font(.largeTitle))
                                            }
                                        }
                                        .frame(width: 220, height: 330)
                                        .cornerRadius(12)
                                        .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 220, height: 330)
                                            .cornerRadius(12)
                                            .overlay(Image(systemName: "film").font(.largeTitle))
                                    }

                                    Text(movie.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .frame(width: 220, alignment: .leading)

                                    if let y = movie.year, !y.isEmpty {
                                        Text(y)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
        }
        .task {
            if appState.vodMovies.isEmpty && appState.activePlaylistId != nil {
                await appState.loadVodForActivePlaylist()
            }
        }
    }
}

// MARK: - Movie Detail View (Backdrop, TMDB info & SubDL Subtitles)
public struct MovieDetailView: View {
    public let movie: MediaItem
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    @State private var detail: VodDetail?
    @State private var isLoading: Bool = true
    @State private var isPlaying: Bool = false
    @State private var showSubtitles: Bool = false
    @State private var subtitles: [SubDLSubtitleItem] = []
    @State private var isSearchingSubs: Bool = false

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            // BACKDROP BANNER
            if let backdrop = detail?.backdropUrl ?? movie.logoUrl, let url = URL(string: backdrop) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), Color.black.opacity(0.75), Color.black.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    // Close Bar & Favorite
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

                        Spacer()

                        Button(action: {
                            appState.toggleFavorite(movie)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: appState.isFavorite(movie) ? "heart.fill" : "heart")
                                Text(appState.isFavorite(movie) ? "Favorited" : "Add to Favorites")
                            }
                            .font(.headline)
                            .foregroundColor(appState.isFavorite(movie) ? .red : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 10)

                    // Hero Content
                    HStack(alignment: .top, spacing: 36) {
                        // Poster
                        if let poster = detail?.posterUrl ?? movie.logoUrl, let url = URL(string: poster) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFit()
                                } else {
                                    Color.gray.opacity(0.3)
                                        .overlay(Image(systemName: "film").font(.largeTitle))
                                }
                            }
                            .frame(width: 240, height: 360)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.7), radius: 16, y: 8)
                        }

                        // Info Column
                        VStack(alignment: .leading, spacing: 14) {
                            Text(detail?.name ?? movie.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            // Badges Row
                            HStack(spacing: 12) {
                                if let rating = detail?.rating ?? movie.rating, !rating.isEmpty, rating != "0" {
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

                                if let date = detail?.releaseDate ?? movie.year, !date.isEmpty {
                                    Text(date.prefix(4))
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(6)
                                }

                                if let dur = detail?.durationMinutes, !dur.isEmpty, dur != "0" {
                                    let mins = Int(dur) ?? 0
                                    let h = mins / 60
                                    let m = mins % 60
                                    Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
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
                                Button(action: {
                                    isPlaying = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                        Text("Watch Movie")
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)

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
                            }
                            .padding(.vertical, 4)

                            // Plot Synopsis
                            if let plot = detail?.plot, !plot.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Synopsis")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(plot)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(4)
                                }
                            }

                            // Cast & Director
                            if let director = detail?.director, !director.isEmpty {
                                HStack {
                                    Text("Director:").fontWeight(.bold).foregroundColor(.secondary)
                                    Text(director)
                                }
                                .font(.footnote)
                            }

                            if let cast = detail?.cast, !cast.isEmpty {
                                HStack(alignment: .top) {
                                    Text("Cast:").fontWeight(.bold).foregroundColor(.secondary)
                                    Text(cast).lineLimit(2)
                                }
                                .font(.footnote)
                            }
                        }
                    }

                    // SUBDL SUBTITLES DRAWER
                    if showSubtitles {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Available Subtitles (SubDL API)")
                                .font(.headline)

                            if isSearchingSubs {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Searching online subtitles…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            } else if subtitles.isEmpty {
                                Text("No subtitles found for this title.")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding()
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                                    ForEach(subtitles) { sub in
                                        Button(action: {
                                            showSubtitles = false
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(sub.language)
                                                        .font(.headline)
                                                    Spacer()
                                                    if sub.hearingImpaired {
                                                        Text("CC").font(.caption2).padding(3).background(Color.white.opacity(0.2)).cornerRadius(4)
                                                    }
                                                }
                                                Text(sub.releaseName)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.card)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)
                    }
                }
                .padding(40)
            }
        }
        .task {
            await loadMovieDetails()
        }
        .fullScreenCover(isPresented: $isPlaying) {
            let streamUrl = detail?.streamUrl ?? movie.streamUrl
            let playItem = MediaItem(
                id: movie.id,
                title: detail?.name ?? movie.title,
                kind: .movie,
                streamUrl: streamUrl,
                logoUrl: detail?.posterUrl ?? movie.logoUrl,
                categoryId: movie.categoryId,
                rating: detail?.rating ?? movie.rating,
                year: detail?.releaseDate ?? movie.year,
                plot: detail?.plot
            )
            PlayerView(item: playItem)
        }
    }

    private func loadMovieDetails() async {
        guard let active = appState.playlists.first(where: { $0.id == appState.activePlaylistId }) else {
            isLoading = false
            return
        }
        let (u, p) = XtreamService.extractCredentials(from: active.url, user: active.username, pass: active.password)
        guard !u.isEmpty && !p.isEmpty else {
            isLoading = false
            return
        }
        if let d = await XtreamService.fetchVodDetails(serverUrl: active.url, user: u, pass: p, streamId: movie.id) {
            self.detail = d
        }
        self.isLoading = false
    }

    private func searchSubtitles() async {
        isSearchingSubs = true
        let cleanTitle = movie.title
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "★", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tmdb = detail?.tmdbId.flatMap(Int.init)
        let yr = (detail?.releaseDate ?? movie.year).flatMap { String($0.prefix(4)) }.flatMap(Int.init)

        let results = await SubDLService.searchSubtitles(title: cleanTitle, tmdbId: tmdb, year: yr)
        self.subtitles = results
        self.isSearchingSubs = false
    }
}
