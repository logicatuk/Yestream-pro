import SwiftUI

// MARK: - Search Category Filter
public enum SearchCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case live = "Live TV"
    case movies = "Movies"
    case series = "Series"

    public var id: String { rawValue }
}

// MARK: - Unified Instant Search View (Option 3)
public struct SearchView: View {
    @ObservedObject var appState = AppState.shared

    @State private var query: String = ""
    @State private var selectedFilter: SearchCategoryFilter = .all

    // Navigation Modals
    @State private var playingItem: MediaItem?
    @State private var selectedMovie: MediaItem?
    @State private var selectedSeries: SeriesItem?

    public init() {}

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var matchingChannels: [MediaItem] {
        guard !cleanQuery.isEmpty else { return [] }
        return appState.channels.filter {
            $0.title.localizedCaseInsensitiveContains(cleanQuery) ||
            ($0.categoryName?.localizedCaseInsensitiveContains(cleanQuery) ?? false)
        }
    }

    public var matchingMovies: [MediaItem] {
        guard !cleanQuery.isEmpty else { return [] }
        return appState.vodMovies.filter {
            $0.title.localizedCaseInsensitiveContains(cleanQuery) ||
            ($0.categoryName?.localizedCaseInsensitiveContains(cleanQuery) ?? false) ||
            ($0.year?.contains(cleanQuery) ?? false)
        }
    }

    public var matchingSeries: [SeriesItem] {
        guard !cleanQuery.isEmpty else { return [] }
        return appState.seriesList.filter {
            $0.title.localizedCaseInsensitiveContains(cleanQuery) ||
            ($0.categoryName?.localizedCaseInsensitiveContains(cleanQuery) ?? false)
        }
    }

    private var totalResultsCount: Int {
        matchingChannels.count + matchingMovies.count + matchingSeries.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ==========================================
            // 1. TOP SEARCH & FILTER BAR
            // ==========================================
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))

                        TextField("Search channels, movies, and series…", text: $query)
                            .font(.system(size: 20, weight: .medium))

                        if !query.isEmpty {
                            Button(action: { query = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Quick Filter Pills
                    HStack(spacing: 10) {
                        ForEach(SearchCategoryFilter.allCases) { filter in
                            Button(action: {
                                selectedFilter = filter
                            }) {
                                HStack(spacing: 6) {
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    Text(filter.rawValue)
                                        .font(.system(size: 14, weight: selectedFilter == filter ? .bold : .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedFilter == filter ? Color.cyan : Color.white.opacity(0.15))
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 24)
            }

            Divider()
                .padding(.top, 20)
                .padding(.bottom, 10)

            // ==========================================
            // 2. MAIN RESULTS / EMPTY STATE
            // ==========================================
            if cleanQuery.isEmpty {
                // Empty Prompt
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.3))

                    VStack(spacing: 8) {
                        Text("Search Across All Entertainment")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Type any channel name, movie, series, or genre above.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 16) {
                            statBadge(icon: "tv", label: "\(appState.channels.count) Live Channels")
                            statBadge(icon: "film", label: "\(appState.vodMovies.count) Movies")
                            statBadge(icon: "play.tv", label: "\(appState.seriesList.count) Series")
                        }
                        .padding(.top, 12)
                    }

                    Spacer()
                }
            } else if totalResultsCount == 0 {
                // No Results
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "slash.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No results for \"\(cleanQuery)\"")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Check your spelling or try searching with fewer keywords.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
            } else {
                // Results Content
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 36) {
                        // LIVE CHANNELS
                        if (selectedFilter == .all || selectedFilter == .live) && !matchingChannels.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                    Text("Live Channels (\(matchingChannels.count))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(matchingChannels.prefix(25)) { ch in
                                            Button(action: {
                                                appState.addToHistory(ch)
                                                playingItem = ch
                                            }) {
                                                HStack(spacing: 12) {
                                                    if let logo = ch.logoUrl, let u = URL(string: logo) {
                                                        AsyncImage(url: u) { phase in
                                                            if let img = phase.image {
                                                                img.resizable().scaledToFit()
                                                            } else {
                                                                Image(systemName: "tv")
                                                                    .foregroundColor(.white.opacity(0.4))
                                                            }
                                                        }
                                                        .frame(width: 36, height: 36)
                                                    } else {
                                                        Image(systemName: "tv")
                                                            .foregroundColor(.white.opacity(0.4))
                                                            .frame(width: 36, height: 36)
                                                    }

                                                    VStack(alignment: .leading, spacing: 3) {
                                                        Text(ch.title.cleanedIptvTitle)
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)

                                                        if let cat = ch.categoryName, !cat.isEmpty {
                                                            Text(cat)
                                                                .font(.system(size: 11))
                                                                .foregroundColor(.white.opacity(0.55))
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    Spacer()
                                                }
                                                .padding(12)
                                                .frame(width: 260, height: 60)
                                                .background(Color.white.opacity(0.06))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }

                        // MOVIES
                        if (selectedFilter == .all || selectedFilter == .movies) && !matchingMovies.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 8) {
                                    Image(systemName: "film.fill").foregroundColor(.cyan)
                                    Text("Movies (\(matchingMovies.count))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(matchingMovies.prefix(25)) { movie in
                                            Button(action: {
                                                selectedMovie = movie
                                            }) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    if let logo = movie.logoUrl, let url = URL(string: logo) {
                                                        AsyncImage(url: url) { phase in
                                                            if let img = phase.image {
                                                                img.resizable().scaledToFill()
                                                            } else {
                                                                Color.gray.opacity(0.3)
                                                                    .overlay(Image(systemName: "film").font(.title))
                                                            }
                                                        }
                                                        .frame(width: 170, height: 255)
                                                        .cornerRadius(12)
                                                        .clipped()
                                                    } else {
                                                        Color.gray.opacity(0.3)
                                                            .frame(width: 170, height: 255)
                                                            .cornerRadius(12)
                                                            .overlay(Image(systemName: "film").font(.title))
                                                    }

                                                    Text(movie.title.cleanedIptvTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 170, alignment: .leading)

                                                    if let y = movie.year, !y.isEmpty {
                                                        Text(y)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                }
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }

                        // SERIES
                        if (selectedFilter == .all || selectedFilter == .series) && !matchingSeries.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.tv.fill").foregroundColor(.orange)
                                    Text("Series (\(matchingSeries.count))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(matchingSeries.prefix(25)) { series in
                                            Button(action: {
                                                selectedSeries = series
                                            }) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    if let cover = series.coverUrl, let url = URL(string: cover) {
                                                        AsyncImage(url: url) { phase in
                                                            if let img = phase.image {
                                                                img.resizable().scaledToFill()
                                                            } else {
                                                                Color.gray.opacity(0.3)
                                                                    .overlay(Image(systemName: "play.tv").font(.title))
                                                            }
                                                        }
                                                        .frame(width: 170, height: 255)
                                                        .cornerRadius(12)
                                                        .clipped()
                                                    } else {
                                                        Color.gray.opacity(0.3)
                                                            .frame(width: 170, height: 255)
                                                            .cornerRadius(12)
                                                            .overlay(Image(systemName: "play.tv").font(.title))
                                                    }

                                                    Text(series.title.cleanedIptvTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 170, alignment: .leading)

                                                    if let rating = series.rating, !rating.isEmpty, rating != "0" {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                                                            Text(rating).font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                                                        }
                                                    }
                                                }
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
        }
        .fullScreenCover(item: $playingItem) { item in
            PlayerView(item: item)
        }
        .fullScreenCover(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
        }
        .fullScreenCover(item: $selectedSeries) { series in
            SeriesDetailView(series: series)
        }
    }

    private func statBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
}
