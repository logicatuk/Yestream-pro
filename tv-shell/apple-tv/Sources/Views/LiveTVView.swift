import SwiftUI

public struct LiveTVView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedChannel: MediaItem?

    public var filteredChannels: [MediaItem] {
        if appState.selectedCategory.isEmpty || appState.selectedCategory == "ALL" {
            return appState.channels
        }
        return appState.channels.filter { $0.categoryId == appState.selectedCategory }
    }

    public var body: some View {
        HStack(spacing: 0) {
            // CATEGORIES SIDEBAR
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    // ALL CHANNELS ITEM
                    Button(action: {
                        appState.selectedCategory = "ALL"
                    }) {
                        HStack {
                            Text("All Channels")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            if !appState.channels.isEmpty {
                                Text("\(appState.channels.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if appState.selectedCategory == "ALL" || appState.selectedCategory.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)

                    ForEach(appState.categories) { cat in
                        Button(action: {
                            appState.selectedCategory = cat.category_id
                        }) {
                            HStack {
                                Text(cat.category_name)
                                    .lineLimit(1)
                                Spacer()
                                if cat.category_id == appState.selectedCategory {
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

            // CHANNELS GRID
            if appState.isLoadingChannels {
                VStack {
                    Spacer()
                    ProgressView("Loading channels…")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredChannels.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tv.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No channels available.")
                        .font(.headline)
                    Text("Connect a playlist from the Playlists tab to view live TV.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 20)], spacing: 20) {
                        ForEach(filteredChannels) { ch in
                            Button(action: {
                                selectedChannel = ch
                            }) {
                                HStack(spacing: 16) {
                                    if let logo = ch.logoUrl, let url = URL(string: logo) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFit()
                                            } else {
                                                Image(systemName: "tv").font(.title)
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(8)
                                    } else {
                                        Image(systemName: "tv")
                                            .font(.title2)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ch.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(ch.categoryName ?? "Live")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .frame(height: 80)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(item: channel)
        }
        .task {
            if appState.channels.isEmpty && appState.activePlaylistId != nil {
                await appState.loadActivePlaylistCatalog(forceRefresh: false)
            }
        }
    }
}
