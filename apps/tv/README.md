# Yestream TV for LG webOS and Samsung Tizen

A dedicated TV edition of [Yestream](../../README.md) for watching your own
live TV, movies and series with a remote. The same client is packaged separately
for LG webOS and Samsung Tizen. It features real-time cloud synchronization,
split-screen playlist management with QR code pairing, M3U and Xtream Codes
dual-tab support, phone-assisted setup, and account licensing diagnostics.

Yestream is a player: it does not provide channels, playlists or subscriptions.

![Yestream TV home with a featured movie and poster rail](docs/screenshots/home.webp)

_Screenshots use fictional demo content, generated artwork and illustrated
portraits. They are browser captures of the TV interface._

[Compatibility](#compatibility) · [Installation](#installation) ·
[Cloud Playlists & QR Setup](#cloud-playlists-and-quick-connect-qr-setup) ·
[Account & License Management](#account-and-device-settings) ·
[Synchronization](#sync-sources-with-self-hosted-iptvnator) ·
[Screenshots](#screenshots)

## Features

- **Split-Screen Playlists Management**: Modern dual-pane view with a persistent Quick Connect QR card on the left and playlist manager on the right.
- **Instant Cloud Sync**: TV registers with Yestream Cloud (`/api/v1/devices/register`) and synchronizes playlists automatically via `/api/v1/device/sync`.
- **Customer Self-Service QR Code**: Direct scan with smartphone opens the authenticated customer portal (`https://yestream.ai.studio/customer/login`) to add/edit playlists remotely without remote-control typing.
- **Dual-Tab Playlist Modal**: Easy on-device addition of both **Xtream Codes API** (Server URL, Username, Password) and **M3U Playlists** (URL / name).
- **Account & Device Diagnostics**: Dedicated Settings tab displaying Hardware MAC Address, 6-digit Device Key, Platform / Model details, and live Subscription / Trial expiration.
- **Expiration Guard**: Clean full-screen lock screen when license or trial expires, displaying instant reactivation QR code and credentials.
- **Live TV & EPG**: Channel categories, search, and multi-channel TV Guide schedule grid from Xtream and Stalker.
- **VOD & Series Catalogs**: Rich poster rails, season/episode drawers, continue watching, and resume positions.
- **Remote & Pointer Navigation**: Seamless D-pad arrows, OK, Back, and LG Magic Remote pointer support.
- **Optional TMDB Metadata**: Movie and series artwork, plot summaries, year/genre chips, and cast filmographies using your own TMDB API key.
- **Native Video Engine**: Hardware-accelerated TV playback with live preview, fullscreen switching, audio track selection, and subtitles.

## Compatibility

| Platform | Status |
| --- | --- |
| LG webOS 5.x / Chromium 68 | Compatibility target. Hardware validation uses an LG BX (2020). |
| Later LG webOS versions | Hardware testing pending. |
| LG webOS 4.x and earlier | Below the current compatibility target. |
| Samsung Tizen 5.5+ | Experimental build target. Community tested on Samsung Q60C (2023) with Tizen 9.0. See the [device test results](../../docs/development/tv-tizen-validation.md#community-device-test). |
| Android TV and other TV platforms | No package available. |

The build targets Chromium 68. LG lists the engine used by each platform in its
[webOS compatibility table](https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine).
Stream formats, codecs, audio and seeking depend on the TV and provider; a
successful browser test does not establish native playback compatibility.

A matching **IPTVnator web backend is required**, even when sources are entered
directly on the TV. Host it on a computer, NAS or server reachable from the TV
and phone. The backend handles provider API requests and phone setup; streams
play directly on the TV. Shared server sources are optional.

## Installation

For Samsung, follow the [Tizen guide](tizen/README.md) to build, sign and install
a `.wgt` package in Developer Mode. The steps below cover LG webOS and its
locally built `.ipk` package. The TV application has its own package version,
declared in [`public/appinfo.json`](public/appinfo.json), independently of the
desktop app.

### 1. Prepare the backend

The [self-hosted Docker setup](../../docker/README.md) includes the backend,
phone setup page and server source library. Build it from the same checkout as
the TV app; an older backend may lack the required TV APIs.

In [`docker/docker-compose.yml`](../../docker/docker-compose.yml), include both
your web origin and the packaged TV origin in `CLIENT_URL`:

```yaml
services:
    iptvnator:
        environment:
            CLIENT_URL: 'http://iptvnator.home.test:4333,file://com.iptvnator.tv.prototype-webos'
```

This is an environment excerpt; keep the rest of the Compose configuration.
Replace `iptvnator.home.test` with your server's hostname or IP address. Use
that same address from the TV and phone; `localhost` on the TV means the TV
itself. For a reverse proxy, allow its actual web origin instead.

From the repository root, start the matching self-hosted build:

```sh
docker compose -f docker/docker-compose.yml up --build -d
```

With the example address above, the backend URL to enter on the TV is
`http://iptvnator.home.test:4333/api`. If server access is protected, enter its
access token on the TV too. Keep the backend on a trusted network; enable
`IPTVNATOR_PROXY_ALLOW_PRIVATE_NETWORKS` only when your provider endpoints
intentionally use private network addresses, as described in the Docker guide.

For an existing self-hosted installation that needs a separate TV backend, see
the [optional companion deployment](../../docker/tv/README.md).

### 2. Build the TV package

Clone the repository, then run these commands from its root. Use the Node
version in [`.nvmrc`](../../.nvmrc) and the pnpm version in
[`package.json`](../../package.json); the pinned webOS CLI is installed with
the project dependencies.

```sh
nvm install
nvm use
corepack enable
pnpm install --frozen-lockfile
pnpm nx run tv:package
```

The command builds and verifies the TV app, then writes the package to
`dist/tv-package/`. The current production package is:
`dist/tv-package/com.yestream.tv.prototype_0.25.6_all.ipk`.

### 3. Enable Developer Mode and connect your TV

Follow LG's [Developer Mode setup guide](https://webostv.developer.lge.com/develop/getting-started/developer-mode-app):

1. Install **Developer Mode** from LG Apps on the TV and sign in with an
   LG Developer account.
2. Enable **Dev Mode Status** and let the TV restart. Keep your computer and TV
   on the same network.
3. On your computer, run `pnpm exec ares-setup-device` and choose **add**. Use
   a device name such as `living-room-tv`, the address shown on your TV (e.g. `192.168.11.120`),
   port `9922` and SSH user `prisoner`.
4. Enable **Key Server** in the TV's Developer Mode app, then retrieve the key:

```sh
pnpm exec ares-novacom --device living-room-tv --getkey
```

Enter the 6-character passphrase shown on your TV when prompted.

> [!TIP]
> **macOS OpenSSH Note**: Modern macOS OpenSSH disables older `ssh-rsa` key algorithms by default.
> If `ares-install` or `ares-novacom` fails with `no matching host key type found` or authentication failure,
> ensure your `~/.ssh/config` contains:
> ```ssh-config
> Host 192.168.11.*
>     HostKeyAlgorithms +ssh-rsa
>     PubkeyAcceptedKeyTypes +ssh-rsa
> ```
> If the downloaded key (`~/.ssh/lgtv_webos`) is passphrase-encrypted, you can decrypt it for automated scripts:
> `openssl rsa -in ~/.ssh/lgtv_webos -out ~/.ssh/lgtv_webos_decrypted -passin pass:<YOUR_PASSPHRASE>`.

### 4. Install and launch

From the repository root, install the package and launch it:

```sh
pnpm exec ares-install --device living-room-tv dist/tv-package/com.yestream.tv.prototype_0.25.6_all.ipk
pnpm exec ares-launch --device living-room-tv com.yestream.tv.prototype
```

Developer Mode has a session timer. Use **EXTEND** in LG's Developer Mode app
before it expires; LG removes developer-installed apps when Developer Mode is
disabled.

## Cloud Playlists and Quick Connect QR Setup

Yestream TV features an intuitive split-screen Playlists interface accessible directly from the main navigation:

### Left Pane: Quick Connect Card
- **Dynamic QR Code**: Scan with any smartphone camera to immediately open your authenticated customer self-service portal:
  `https://yestream.ai.studio/customer/login?mac=<MAC>&key=<KEY>&redirect=/me/playlists`
- **Device Credentials**: Displays your TV's Hardware MAC address and 6-digit Device Key for manual portal entry or reseller activation.
- **License Status**: Live status badge showing `TRIAL`, `ACTIVE`, or `EXPIRED`.
- **↻ Sync Cloud Playlists Button**: Click to immediately pull down the latest playlists configured in your customer web portal. The TV client automatically registers with `/api/v1/devices/register` and synchronizes from `/api/v1/device/sync` (with automatic 401 re-registration recovery).

### Right Pane: Configured Playlists & Modal
- **Active Playlist Selection**: Visual indicator showing the active playlist powering Live TV, Movies, and Series.
- **+ Add Playlist Button**: Opens a dual-tab modal directly on the TV:
  1. **Xtream Codes API**: Enter Server URL, Username, Password, and Playlist Name.
  2. **M3U Playlist**: Enter M3U/M3U8 URL and Playlist Name.
- **Delete / Manage**: Remove old playlists or switch between multiple providers instantly.

## Account and Device Settings

Navigate to **Settings → Account & Device** to view full hardware and subscription details:
- **Device MAC Address**: Live hardware MAC address (with SHA-256 virtual MAC fallback).
- **Device Key**: 6-digit one-time access key.
- **Platform & Model**: Detected platform (`LG TV · LG Smart TV (webOS 5.x+)` or `Samsung TV · Samsung Smart TV (Tizen 5.5+)`) and app version `v0.25.6`.
- **License Expiration**: Expiration date of your active plan or trial.
- **Renewal QR Code**: Instant QR code linking directly to license extension and renewal.

## Expiration Guard Lock Screen

If your trial or license expires, Yestream TV activates an Expiration Guard lock screen:
- Prevents stream playback while displaying your TV's MAC address and Device Key.
- Provides a direct QR code to renew or activate online.
- Features a **Check License Status** button to unlock the player immediately once renewed.

## Sync sources with self-hosted IPTVnator

The TV can connect to the source library of your self-hosted IPTVnator. If your
selected backend offers it, choose **Use this server’s sources**. To enter a
separate address or token:

1. Open **Settings → Library & sync → Server library**.
2. Enter the **Library server URL** and optional **Library access token**.
   For the bundled Docker deployment, use the same backend base URL as above,
   for example `http://iptvnator.home.test:4333/api`.
3. Choose **Connect library**. Manage shared source definitions in the PWA.

| Data                                                                            | TV behavior                                              |
| ------------------------------------------------------------------------------- | -------------------------------------------------------- |
| M3U URLs and uploaded/pasted M3U content, Xtream and Stalker source definitions | Read from the connected server library.                  |
| Source edits and removals made in the PWA                                       | Applied to linked TV entries on refresh.                 |
| A source entered locally on the TV                                              | Uploaded only when you select **Copy source to server**. |
| Favorites, watch history and resume positions                                   | Stay local to the TV; not synchronized across devices.   |
| TV settings and TMDB preferences                                                | Stay local to the TV.                                    |

Sources refresh on launch, when returning to the app and every minute while
the app is visible and not playing. **Refresh library now** requests an update
manually. **Disconnect library** keeps downloaded sources as local copies and
preserves local viewing data. This feature shares sources; it does not relay
video or synchronize TV viewing activity with the desktop/PWA.

## Optional TMDB metadata

Open **Settings → Metadata · TMDB**, enable **Use TMDB metadata**, enter your own
v3 API key or v4 read access token, choose a metadata language and save. Checking
the key alone does not enable or save metadata. You can also enter the key
through phone setup.

When available, metadata adds artwork, descriptions, year/genre/country chips,
duration, ratings, cast, filmographies and episode details. Provider sources
remain authoritative for playback. The TV needs direct access to TMDB's API
and image servers; metadata failures leave provider content usable.

## Screenshots

| Movie details with metadata and cast                                                                 | Series details with creator and cast                                                    |
| ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| ![Movie details with genre, country, duration, rating and cast](docs/screenshots/movie-details.webp) | ![Series details with metadata, creator and cast](docs/screenshots/series-details.webp) |

All screenshots use the local synthetic demo catalog. The
[capture instructions](../../docs/development/tv-development.md#synthetic-screenshots)
describe how to reproduce them without provider accounts or real TMDB keys.

## Current limitations

- Experimental device support; provider and native playback compatibility
  still require testing on your TV.
- Programme guides come from Xtream and Stalker; M3U XMLTV and archive/catch-up
  playback are not included.
- No DRM, downloads, transcoding or desktop MPV/VLC integrations.
- Native video cannot attach arbitrary provider headers such as MAG cookies
  or custom User-Agent/Referer values. Some streams therefore need capabilities
  outside this client.

## Development and troubleshooting

- [TV development guide](../../docs/development/tv-development.md) — local runs,
  backend configuration, packaging and device validation.
- [TV architecture](../../docs/architecture/tv-application.md) — provider,
  playback, storage and synchronization contracts.
- [Docker guide](../../docker/README.md) — self-hosting, tokens and networking.
- [TV companion backend](../../docker/tv/README.md) — a separate deployment
  alongside an existing server library.

When reporting a problem, include the app build and device information shown
in **Settings → About**, your TV's OS version and source type. Do not include
provider credentials, access tokens or private stream URLs.
