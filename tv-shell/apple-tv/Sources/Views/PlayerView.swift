import SwiftUI
import AVKit

public struct PlayerView: View {
    public let item: MediaItem
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer?
    @State private var showSubtitlesDrawer: Bool = false
    @State private var subtitles: [SubDLSubtitleItem] = []
    @State private var isSearchingSubs: Bool = false

    public var body: some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        p.play()
                    }
                    .onDisappear {
                        p.pause()
                    }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
                ProgressView("Connecting to stream…")
            }

            // Subtitles Drawer Overlay
            if showSubtitlesDrawer {
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Subtitles (SubDL Engine)")
                                .font(.headline)
                            Spacer()
                            Button("Close") {
                                showSubtitlesDrawer = false
                            }
                        }

                        if isSearchingSubs {
                            ProgressView("Searching SubDL database…")
                        } else if subtitles.isEmpty {
                            Text("No online subtitles found.")
                                .foregroundColor(.secondary)
                        } else {
                            List(subtitles) { sub in
                                Button(action: {
                                    // Subtitle selection
                                    showSubtitlesDrawer = false
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(sub.language).fontWeight(.bold)
                                        Text(sub.releaseName).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(width: 450)
                    .background(Color.black.opacity(0.9))
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            if let url = URL(string: item.streamUrl) {
                self.player = AVPlayer(url: url)
            }
        }
    }
}
