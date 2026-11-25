# Store Submission — Yestream

This directory holds the store listing metadata for every distribution channel. Each platform folder mirrors the layout its upload tool expects, so the same files are used both by humans and by the `fastlane` / Partner Center / vendor uploaders.

## Layout

```
store/
├── common/              shared values (support email, policy URLs)
├── android/             Google Play (fastlane supply layout) + TWA config
├── apple/               App Store Connect (fastlane deliver layout) — macOS first
├── windows/             Microsoft Store listing (Partner Center copy)
├── lg-webos/            LG Content Store (.ipk listing)
├── samsung-tizen/       Samsung Seller Office (.wgt listing)
└── amazon/              Amazon Appstore (APK / Vega listing)
```

## Build artifacts

| Store | Artifact | Produced by |
|-------|----------|-------------|
| Google Play | `.aab` / `.apk` | `tv-shell/android` gradle + `bubblewrap` for TWA |
| App Store (Mac) | `.dmg` + notarized `.app` | `pnpm run make:app` |
| Microsoft Store | `.msix` | electron-builder MSIX target |
| LG webOS | `.ipk` | `pnpm --filter tv package` |
| Samsung Tizen | `.wgt` | `pnpm --filter tv package-tizen` |
| Amazon (Vega) | `.vpkg` | `pnpm --filter tv package-vega` |
| Amazon (Fire TV) | `.apk` | tv-shell gradle |

## Before submitting

1. Replace placeholders in `android/twa/assetlinks.json` with the release keystore SHA-256 fingerprint, and host it at `https://yestream.ai.studio/.well-known/assetlinks.json`.
2. Put the Play service-account JSON at `android/fastlane/google-play-service-account.json` (never commit it).
3. Fill `apple/fastlane/Appfile` with the Apple team ID, and provide an App Store Connect API key.
4. Generate 8–10 screenshots per platform into each `images/` folder (phone/tablet/TV/desktop).
5. Add the release keystore and signing certificates to CI secrets.

## Draft copy

Canonical title/description/keywords live in `android/metadata/en-US/`. The Apple, Windows and vendor folders carry the same wording adapted to each store's length limits (Apple subtitle ≤30, Windows short description ≤300, etc.). When the copy changes, update all six folders and `common/`.