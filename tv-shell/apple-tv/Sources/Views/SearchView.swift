import SwiftUI

public struct SearchView: View {
    @ObservedObject var appState = AppState.shared
    @State private var query: String = ""
    @State private var playingItem: MediaItem?

    public var matchingChannels: [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.channels.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    public var matchingMovies: [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.vodMovies.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    public var matchingSeries: [SeriesItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.seriesList.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search channels, movies, and series…", text: $query)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            if query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Find your next story")
                        .font(.headline)
                    Text("Search across your live TV channels, movie titles, and series.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if matchingChannels.isEmpty && matchingMovies.isEmpty && matchingSeries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No results for \"\(query)\"")
                        .font(.headline)
                    Spacer()
                }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 30) {
                        // LIVE CHANNELS RESULTS
                        if !matchingChannels.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Live Channels (\(matchingChannels.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(matchingChannels.prefix(20)) { ch in
                                            Button(action: {
                                                appState.addToHistory(ch)
                                                playingItem = ch
                                            }) {
                                                HStack {
                                                    Image(systemName: "tv")
                                                    Text(ch.title).lineLimit(1)
                                                }
                                                .padding()
                                                .frame(width: 240)
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }

                        // MOVIES RESULTS
                        if !matchingMovies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Movies (\(matchingMovies.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(matchingMovies.prefix(20)) { movie in
                                            Button(action: {
                                                appState.addToHistory(movie)
                                                playingItem = movie
                                            }) {
                                                VStack(alignment: .leading) {
                                                    if let logo = movie.logoUrl, let url = URL(string: logo) {
                                                        AsyncImage(url: url) { phase in
                                                            if let img = phase.image {
                                                                img.resizable().scaledToFill()
                                                            } else {
                                                                Color.gray.opacity(0.3)
                                                            }
                                                        }
                                                        .frame(width: 160, height: 240)
                                                        .cornerRadius(10)
                                                        .clipped()
                                                    }
                                                    Text(movie.title).font(.caption).lineLimit(1).frame(width: 160)
                                                }
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }

                        // SERIES RESULTS
                        if !matchingSeries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Series (\(matchingSeries.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(matchingSeries.prefix(20)) { s in
                                            VStack(alignment: .leading) {
                                                if let cover = s.coverUrl, let url = URL(string: cover) {
                                                    AsyncImage(url: url) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().scaledToFill()
                                                        } else {
                                                            Color.gray.opacity(0.3)
                                                        }
                                                    }
                                                    .frame(width: 160, height: 240)
                                                    .cornerRadius(10)
                                                    .clipped()
                                                }
                                                Text(s.title).font(.caption).lineLimit(1).frame(width: 160)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(item: $playingItem) { item in
            PlayerView(item: item)
        }
    }
}
