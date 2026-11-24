# Yestream TV

<!-- impeccable:product-schema 1 -->

## Platform

web (LG webOS 5.x+, Samsung Tizen 5.5+)

## Users

Viewers using their own IPTV playlists on a television, navigating with a remote
or pointer. The maintainer confirmed that everyday viewers and experienced IPTV
users are equally important: make the main viewing path simple while retaining
access to advanced playlist, cloud sync, and playback settings.

## Product Purpose

This is a dedicated TV client designed for 10-foot television experiences.
The main product and primary focus for product and design work is the [Electron/PWA player](../web/PRODUCT.md) under
`apps/web`. TV support delivers a remote-friendly, TV-optimized interface for Smart TVs.

Let users browse, watch and resume their own live TV, movies and series on the
television. Yestream supplies the player, not channels or subscriptions.

## Positioning

A dedicated TV client supports M3U playlists, Xtream Codes API, and Stalker/Ministra portals,
directional navigation, native television playback, split-screen playlist management with
Quick Connect QR code pairing, instant cloud sync with Yestream Cloud, and account diagnostics.
It shares provider contracts with the wider project while retaining its own
runtime, navigation and local viewing state.

## Operating Context

- Preact 10 and Vite build a web application packaged for LG webOS (`.ipk`) and Samsung Tizen (`.wgt`).
  The current approved device target is LG webOS 5.x+ (Chromium 68+) and Samsung Tizen 5.5+ (Chromium 69+).
- Split-screen Playlists interface with a persistent Quick Connect QR card directing users to
  the customer self-service portal (`https://yestream.ai.studio/customer/login?mac=<MAC>&key=<KEY>&redirect=/me/playlists`).
- Dual-tab modal for direct playlist addition (`Xtream Codes API` and `M3U Playlist`).
- Automatic cloud synchronization (`/api/v1/devices/register` and `/api/v1/device/sync`) with
  automatic 401 re-registration recovery.
- Account & Device settings panel displaying hardware MAC, 6-digit Device Key, platform model, and license status.
- Expiration Guard lock screen preventing unauthorized playback when subscriptions or trials expire.
- `apps/tv-setup` provides the companion phone form for local setup sessions.
- Development starts from the repository root with `pnpm nx serve tv` on port 4310.

## Capabilities and Constraints

- Use the TV's native video adapter. The TV runtime excludes Angular, NgRx, RxJS,
  Electron and Node; desktop player integrations are not available here.
- Preserve Chromium 68 compatibility and packaged `file://` startup behavior.
- Instant cloud synchronization connects with Yestream Cloud backend while maintaining
  fallback to self-hosted server sources.
- Dual-tab playlist onboarding simplifies entering Xtream and M3U credentials directly on TV.
- Xtream and Stalker supply programme guides. M3U XMLTV, archive playback and
  DRM are outside the current TV scope.
- Focus and browsing must not start or replace playback. Preserve directional
  navigation, platform Back, modal focus ownership and return to the originating
  item after playback or detail navigation.
- Customer QR portal minimizes typing on television remotes. Source
  credentials and resolved stream URLs are not logged.
- Browser tests provide development evidence; they do not certify the real
  television's remote, codecs or native playback behavior.

## Brand Commitments

Keep the Yestream identity and distinguish TV playback from desktop remote
control. The maintainer prohibits decorative vertical side borders or accent
strips, including shadow and pseudo-element imitations.

## Evidence on Hand

- [TV architecture and cloud sync](../../docs/architecture/tv-application.md).
- [Development and device validation](../../docs/development/tv-development.md).
- [TV phone setup application](../tv-setup/project.json).
- [Existing TV entry point](src/main.tsx) and [TV feature implementation](../../libs/tv/feature/project.json).

## Product Principles

1. Keep the TV scope remote-friendly, responsive, and tailored for 10-foot UI.
2. Keep playlist setup and everyday viewing simple, with advanced settings accessible.
3. Maintain predictable focus, Back behavior and deliberate playback actions.
4. Seamless cloud synchronization via QR code without remote-typing friction.
5. Judge TV readiness with actual device evidence as well as browser checks.

## Accessibility & Inclusion

Directional remote navigation, pointer input and stable, recoverable focus are
core interaction requirements. Preserve readable content at television viewing
distance and usable phone-based entry. No new accessibility certification or
additional device-support commitment was established during init.
