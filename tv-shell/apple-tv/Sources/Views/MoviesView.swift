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
            PlayerView(item: movie)
        }
        .task {
            if appState.vodMovies.isEmpty && appState.activePlaylistId != nil {
                await appState.loadVodForActivePlaylist()
            }
        }
    }
}
