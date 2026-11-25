import SwiftUI

public struct FavoritesView: View {
    @ObservedObject var appState = AppState.shared
    @State private var filterKind: String = "all"
    @State private var playingItem: MediaItem?

    public var filteredFavorites: [MediaItem] {
        if filterKind == "all" {
            return appState.favorites
        }
        return appState.favorites.filter { $0.kind.rawValue == filterKind }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Favorites")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 12) {
                    Button("All") { filterKind = "all" }
                        .buttonStyle(.bordered)
                        .background(filterKind == "all" ? Color.blue.opacity(0.4) : Color.clear)
                        .cornerRadius(8)
                    Button("Live TV") { filterKind = "live" }
                        .buttonStyle(.bordered)
                        .background(filterKind == "live" ? Color.blue.opacity(0.4) : Color.clear)
                        .cornerRadius(8)
                    Button("Movies") { filterKind = "movie" }
                        .buttonStyle(.bordered)
                        .background(filterKind == "movie" ? Color.blue.opacity(0.4) : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            Divider()

            if filteredFavorites.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No favorites saved yet.")
                        .font(.headline)
                    Text("Add your favorite channels and movies to access them quickly here.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 20)], spacing: 20) {
                        ForEach(filteredFavorites) { item in
                            Button(action: {
                                appState.addToHistory(item)
                                playingItem = item
                            }) {
                                HStack(spacing: 16) {
                                    if let logo = item.logoUrl, let url = URL(string: logo) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFit()
                                            } else {
                                                Image(systemName: item.kind == .live ? "tv" : "film")
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                    } else {
                                        Image(systemName: item.kind == .live ? "tv" : "film")
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(item.kind.rawValue.uppercased())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        appState.toggleFavorite(item)
                                    }) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                            }
                            .buttonStyle(.card)
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
