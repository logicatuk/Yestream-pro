# Roku Channel — Yestream

This directory contains the **Roku Channel Store** implementation for Yestream Pro — a native BrightScript/SceneGraph channel that mirrors the web/TV feature set.

## Quick Facts

- **Platform**: Roku (BrightScript / SceneGraph)
- **Backend**: `https://yestream.ai.studio/api/v1` (same as all other platforms)
- **App ID**: `com.yestream.roku.channel`
- **Version**: 0.1.0
- **Estimated effort**: 13-17 days

## Project Structure

```
roku/
├── manifest.manifest           # Channel manifest
├── source/
│   ├── main.brs                # Entry point + screen routing
│   ├── config.brs              # API endpoints + constants
│   ├── device-identity.brs     # MAC + 6-digit key generation
│   ├── cloud-api.brs           # HTTP client (roUrlTransfer)
│   ├── json.brs                # JSON parser/serializer
│   ├── sha256.brs              # SHA-256 implementation
│   ├── qrcode.brs              # QR code rendering (roImageCanvas)
│   ├── access-evaluation.brs   # Trial/active/expired logic
│   ├── playlists.brs           # M3U/Xtream/Stalker parsers
│   ├── epg.brs                 # EPG grid + XMLTV parsing
│   └── licensing.brs           # Expiry guard state machine
├── components/                 # SceneGraph UI
│   ├── YestreamScene.xml       # Root scene
│   ├── HomeScreen.xml          # Dashboard rails
│   ├── LiveTVScreen.xml        # Channel list + EPG
│   ├── PlayerScreen.xml        # roVideoScreen wrapper
│   ├── PlaylistManager.xml     # Playlist management
│   ├── AccountScreen.xml       # Device info + key
│   └── ExpiryLockScreen.xml    # Full-screen activation lock
├── images/                     # Channel icon + splash screen
├── locale/en_US/               # Translations
└── test/                       # Unit tests
```

## Build & Deploy

### Prerequisites
- Roku Developer Account ($25 one-time fee)
- Roku device for testing (or Roku emulator)
- `brighterscript` CLI for linting

### Sideload to Roku
```bash
# Build the channel package
zip -r yestream-roku-channel.zip roku/

# Upload to Roku device
curl -F "mysubmit=Upload" -F "archive=@yesthem-roku-channel.zip" \
  http://<ROKU_IP>/plugin_install
```

### Roku Developer Dashboard
1. Go to https://developer.roku.com/
2. Sign in with your Roku Developer account
3. Click "My Channels" → "Create"
4. Fill in channel details
5. Upload the signed channel package
6. Submit for review

## Requirements

| Item | Status |
|------|--------|
| Manifest | ✅ `roku/manifest.manifest` |
| Config | ✅ `roku/source/config.brs` |
| Core API | ✅ `roku/source/cloud-api.brs` |
| Identity | ✅ `roku/source/device-identity.brs` |
| SHA-256 | ✅ `roku/source/sha256.brs` |
| JSON | ✅ `roku/source/json.brs` |
| QR Code | ✅ `roku/source/qrcode.brs` |
| Licensing | ✅ `roku/source/licensing.brs` |
| UI Components | ✅ 5 SceneGraph XML files |
| Store Metadata | ✅ `store/roku/metadata/en-US/` |
| CI Workflow | ✅ `.github/workflows/build-roku.yml` |

## Known Limitations

- **SHA-256**: Pure BrightScript implementation (slower than native)
- **JSON**: roSGNode-based parser (requires Roku OS 9.0+)
- **QR Code**: Simplified matrix (no error correction)
- **DRM**: Not implemented in v1
- **DRM (PlayReady/Widevine)**: Out of scope for v1

## Testing

To test on a real Roku device:
1. Enable Developer Mode on your Roku device
2. Get your Roku device IP address
3. Use `roku-deploy` or `curl` to upload the channel
4. Test all flows: registration → trial → expiry → activation → unlock