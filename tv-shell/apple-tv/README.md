# Yestream for Apple TV (tvOS)

Native Apple TV (tvOS 16.0+) client for **Yestream**, built with SwiftUI, AVKit, and direct integration with the Yestream Cloud backend and Xtream Codes API.

---

## Features

- **100% Native tvOS Experience**: Built with modern SwiftUI and AVKit for flawless Apple App Store compliance.
- **Siri Remote Navigation**: Native focus engine with automatic card scaling and parallax effects.
- **Instant Cloud Sync (Quick Connect)**: Displays pairing QR code generated on-device with CoreImage (`CIQRCodeGenerator`), persistent hardware MAC address, and 6-digit Device Key.
- **Xtream Codes API & M3U**: Fast streaming category and channel extraction.
- **SubDL Online Subtitles**: Integrated search from SubDL API with automatic language matching.
- **Hardware-Accelerated 4K Playback**: Native Apple AVFoundation player with Dolby Atmos, HDR10, and Dolby Vision support.

---

## Directory Structure

```
tv-shell/apple-tv/
├── Sources/
│   ├── App/
│   │   ├── YestreamTVApp.swift    # App entry point
│   │   └── AppState.swift         # Local playlists, channels, active selection
│   ├── Models/
│   │   ├── DeviceRegistration.swift # Hardware MAC & Cloud registration
│   │   └── Playlist.swift         # Playlist & MediaItem models
│   ├── Services/
│   │   ├── CloudSyncService.swift # Yestream Cloud pairing & sync engine
│   │   ├── XtreamService.swift    # Xtream Codes API parser
│   │   └── SubDLService.swift     # Online SubDL subtitles API
│   └── Views/
│       ├── ContentView.swift      # Main TabView (TV, Playlists, Settings)
│       ├── LiveTVView.swift       # Categories rail & Channel grid
│       ├── PlaylistsView.swift    # Split-screen QR Quick Connect & playlist list
│       ├── PlayerView.swift       # Native AVPlayer with SubDL subtitle drawer
│       ├── QRCodeView.swift       # Crisp vector QR generator
│       └── SettingsView.swift     # Hardware & subscription diagnostics
├── Resources/
│   └── Info.plist                 # tvOS bundle configuration
└── build.sh                       # CLI compiler for Simulator and physical device
```

---

## Building the App

### 1. Build for Apple TV Simulator
```bash
./build.sh simulator
```
Output: `dist/apple-tv/yestream-tvos-simulator.zip` and `dist/apple-tv/Yestream TV.app`.

To install and run in the Simulator:
```bash
xcrun simctl install booted "dist/apple-tv/Yestream TV.app"
xcrun simctl launch booted com.yestream.tv
```

### 2. Build for Physical Apple TV Device
```bash
./build.sh device
```
Output: `dist/apple-tv/yestream-tvos-device.zip`.
Install via Xcode Devices window (**Window > Devices and Simulators**), Apple Configurator, or TestFlight.
