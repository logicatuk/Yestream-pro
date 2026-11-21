# IPTVnator + Yestream Unified Integration Plan (4-Pillar AI Handoff & Backend Upgrade)

Upgrade Yestream's Device API and QR web flows so they act as the **sole backend** for `4gray/iptvnator` across all platforms, and deliver a complete, copy-ready Markdown AI handoff guide covering all four pillars: reinstall-safe virtual MAC & 6-digit Key identity with server-enforced trial expiry lock, complete removal of IPTVnator's own backend without crashing playback, full two-way Playlist CRUD and sync across app/portal/panel, and QR-powered instant portal login & activation.

## User Review & Critical Decisions

> [!IMPORTANT]
> This completely replaces the previous plan to incorporate all four requirements you specified, including **deleting IPTVnator's own backend**, **full two-way App ↔ Panel playlist mirroring**, and **immediate anti-bypass 7-day trial expiration enforcement**.

- **Pillar 1 — Anti-Bypass Identity & Live Trial Lock**: App derives a deterministic virtual MAC (`02:XX:XX:XX:XX:XX`) from persistent hardware/OS identity (`hardwareFingerprint`), receives a server-issued 6-digit Key (`key6`), and fetches dynamic `trialDays` (currently 7 days) from Super Admin settings. Reinstalling the app recovers the **exact same MAC, Key, and original trial end date** so the free trial cannot be reset. Once expired, the app blocks playback and displays an activation lock screen pointing to `https://yestream.ai.studio/activate` + QR code.
- **Pillar 2 — Delete IPTVnator's Built-in Backend**: Remove IPTVnator's standalone web backend (`web-backend`, its Docker proxy wiring, and `BACKEND_URL` calls) cleanly without breaking Angular dependency injection, native desktop playback (Electron/MPV/VLC), or local M3U/Xtream parsing. Yestream (`https://yestream.ai.studio/api/v1`) becomes the **single cloud backend**.
- **Pillar 3 — Full Two-Way Playlist Mirroring (App ↔ Customer Portal ↔ Reseller Panel)**: Playlists added manually inside the app (M3U or Xtream) immediately sync to Yestream so customers and resellers see the exact same list in the panel. Creating, editing, or deleting unlocked playlists works seamlessly from **both** the app and the website/panel, with instant SSE push reload + manual Reload button.
- **Pillar 4 — Seamless QR Deep-Links**:
  - **Playlist QR**: `https://yestream.ai.studio/customer/login?mac=...&key=...&redirect=/me/playlists` auto-logs in and opens Playlists directly.
  - **Activation QR (Trial Expired)**: `https://yestream.ai.studio/activate?mac=...&key=...` pre-fills MAC & Key and auto-looks up the device ready for payment.

---

## 1. Overview & Core Concept

- **What It Does**: Turns Yestream into the single authoritative backend for your customized `4gray/iptvnator` player across Desktop, Web/PWA, Mobile, and Smart TV wrappers — governing device identity, anti-bypass free trials, subscription enforcement, QR pairing, and real-time bidirectional playlist management.
- **Target Audience / Persona**:
  - **End Customers**: Install the player, see their MAC + 6-digit Key and QR code, enjoy the Super Admin–configured free trial (7 days), add M3U/Xtream playlists either inside the app or from their phone via QR, and activate seamlessly when the trial ends.
  - **Super Admins & Resellers**: Configure trial duration globally, see every playlist added by the customer in the app, push/edit/lock playlists remotely, and activate licenses that unlock expired apps in real time.
  - **Your External AI**: Receives a self-contained Markdown specification that explains exactly how to strip IPTVnator's old backend safely, wire Yestream's API endpoints, enforce the trial gate, and preserve smooth playback.
- **Key Value**: One unified backend, zero trial-reset loopholes on reinstall, zero divergence between app playlists and panel playlists, and a crash-proof migration path for IPTVnator.

---

## 2. User Experience & Visual Design

### Key User Flows

1. **First Launch, Identity & Anti-Bypass Recovery (App)**
   - On boot, the player reads stable OS/hardware identity (Windows MachineGuid / macOS IOPlatformUUID / Linux machine-id / Android ID / iOS Keychain / persistent browser seed) to compute a SHA-256 `hardwareFingerprint` and deterministic locally-administered virtual MAC (`02:XX:XX:XX:XX:XX`).
   - Calls Yestream registration. If the device was previously registered—even after uninstalling and reinstalling the app—Yestream matches `hardwareFingerprint` (or MAC) and returns the **original MAC, 6-digit Key, original trial expiry date, license status, and existing playlists**.
2. **Trial Countdown & Hard Expiry Gate (App)**
   - During the active trial (duration controlled live by Super Admin settings, currently 7 days), the app displays remaining trial days alongside the device's MAC and 6-digit Key in the Account/Device Info header or screen.
   - The moment server time passes `expiresAt` (and the device is not `active` or `FOREVER`), Yestream returns `accessAllowed: false` and `status: "expired"`.
   - The player immediately blocks stream playback and overlays a clean **Expired Activation Screen** showing:
     - Clear message: *"Your free trial / license has expired. Please activate your device via QR code or at `https://yestream.ai.studio/activate`."*
     - Prominent MAC Address, 6-digit Device Key, and scannable **Activation QR Code**.
     - **"I've Activated — Refresh Status"** button (plus automatic SSE unlock when payment completes).
3. **Two-Way Playlist Management (App + QR Portal + Reseller Panel)**
   - Inside the app's **Add Playlist** screen, users choose:
     - **Manual M3U / Xtream**: Uses IPTVnator's native M3U and Xtream entry forms, then immediately posts the new playlist to Yestream so it appears in the Customer Portal and Reseller Panel.
     - **Scan QR Code**: Displays the Playlists QR code + MAC + 6-digit Key. Scanning opens `https://yestream.ai.studio/customer/login?...&redirect=/me/playlists`, auto-authenticates, and lands right on the Playlists manager.
   - Editing or deleting any unlocked playlist from the app sends `PATCH` / `DELETE` to Yestream; editing or deleting from the Customer Portal or Reseller Panel bumps `configVersion` and pushes a live reload event to the app (with a manual **Reload Playlists** button and 60-second fallback sync).
   - Reseller-locked playlists (`lockedByReseller: true`) play normally in the app but disable Edit/Delete controls and hide raw credentials in the UI.
4. **QR Activation Web Flow (`https://yestream.ai.studio/activate`)**
   - Scanning the expired-trial QR code opens `/activate?mac=...&key=...`, auto-populates the MAC and 6-digit Key fields, strips sensitive query parameters from the URL bar, and runs the device lookup immediately so the customer can pick a plan and pay in seconds.

### Visual Identity & Theme

- **Aesthetic Direction**: Clean utilitarian dashboard styling aligned with Yestream's existing website and Customer Portal (crisp white elevated cards, slate borders, indigo primary CTAs, emerald live-sync badges, and amber badges for reseller-locked or expiring-trial states).
- **Color Palette & Mood**: High-contrast light surfaces on web portals (`--background` slate-50, `--primary` indigo-600, `--destructive` rose-600 for expired notices) with strict `dir="ltr"` monospace formatting (`font-mono tabular-nums`) for all MAC addresses, 6-digit keys, and URLs.
- **Typography & Hierarchy**: Bold geometric headings paired with clear tabular monospace codes so customers can visually match MAC + Key between TV/desktop and phone effortlessly.
- **Interactive Feedback & Motion**: Smooth loading states during QR auto-login and `/activate` auto-lookup, instant confirmation toasts when playlists sync, and clear disabled states on locked reseller playlists.

---

## 3. Key Product Decisions & Trade-Offs

- **Decision 1: Server-Authoritative Trial Expiry & Fingerprint Matching (Zero Bypass)**
  - *Chosen Approach*: Match returning devices by `hardwareFingerprint` **first**, then normalized MAC; compute live expiration on every registration, sync, entitlement, and heartbeat call using server UTC time (`Date.now() > expiresAt`), automatically transitioning expired records to `status: "expired"` and returning `accessAllowed: false`.
  - *Why*: Client clocks can be rolled back and local storage can be wiped by uninstalling the app. Checking hardware fingerprint and UTC expiry on Yestream's server closes both loopholes completely.
  - *Alternatives Considered*: Tracking trial dates locally inside Electron SQLite or IndexedDB — rejected because uninstalling the app would reset the 7-day trial.

- **Decision 2: Surgical Deletion of IPTVnator's `web-backend` Without Breaking Desktop Playback**
  - *Chosen Approach*: Remove `apps/web-backend`, its Docker proxy service, and all `BACKEND_URL` references completely. Keep Electron's local desktop runtime (window shell, native MPV/VLC process bridge, local channel/EPG cache) because it is the native player shell—not a remote server—and route all cloud identity, playlist CRUD, sync, and licensing strictly to Yestream (`https://yestream.ai.studio/api/v1`). Document exact direct-fetch handling so browser/PWA builds gracefully handle CORS without needing `web-backend`.
  - *Why*: Meets your requirement to eliminate IPTVnator's backend completely while preventing the external AI from accidentally deleting Electron's native video player IPC and crashing the app.
  - *Alternatives Considered*: Keeping `apps/web-backend` running alongside Yestream — rejected per your explicit instruction to maintain only one backend.

- **Decision 3: Complete REST Playlist CRUD + Short-Lived SSE Tokens for Real-Time Sync**
  - *Chosen Approach*: Add explicit `GET` and `PATCH` routes alongside `POST`, `DELETE`, and `/sync` on Yestream's Device Playlists API, plus a short-lived SSE event token route (`POST /device/events/token`) so Web, Mobile, TV, and Electron clients receive instant playlist and license-activation updates without placing long-lived bearer credentials in URLs.
  - *Why*: Ensures true 1:1 mirror consistency between app and panel in both directions across every platform.

---

## 4. Technical Architecture & Data Strategy

### System & Integration Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                Customized IPTVnator App (All Platforms)                    │
│          [Old apps/web-backend & BACKEND_URL Completely Removed]           │
│                                                                            │
│  ┌──────────────────────────────┐     ┌─────────────────────────────────┐  │
│  │ Identity & Trial Gate        │     │ Two-Way Playlist Manager        │  │
│  │ • OS/Hardware Fingerprint    │     │ • Manual M3U & Xtream Forms     │  │
│  │ • Virtual MAC (02:XX:...)    │     │ • Cloud CRUD -> Yestream API    │  │
│  │ • Server 6-Digit Key         │     │ • QR Pairing + Reload + SSE     │  │
│  │ • Hard Lock Screen on Expiry │     │ • Reseller-Locked Read-Only UI  │  │
│  └──────────────┬───────────────┘     └────────────────┬────────────────┘  │
│                 └──────────────────┬───────────────────┘                   │
│                                    │ HTTPS REST + SSE                      │
│  ┌─────────────────────────────────▼────────────────────────────────────┐  │
│  │ Preserved Core Media Engine (Unchanged)                              │  │
│  │ • Native Players (MPV / VLC / HTML5 / HLS.js / Shaka)                │  │
│  │ • M3U / Xtream / EPG Parsers & Local Playback Cache                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────┼───────────────────────────────────────┘
                                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│             Yestream Sole Backend (https://yestream.ai.studio)             │
│                                                                            │
│  • POST /api/v1/devices/register                                           │
│      -> Matches hardwareFingerprint OR MAC (prevents reinstall bypass)     │
│      -> Returns MAC, key6, credential, dynamic trialDays, accessAllowed,   │
│         portalPlaylistsUrl, activateUrl                                    │
│  • GET  /api/v1/device/sync & GET /api/v1/device/entitlement               │
│      -> Live UTC expiry check (flips trial -> expired automatically)       │
│      -> Returns configVersion, accessAllowed, trialRemainingDays, playlists│
│  • GET / POST / PATCH / DELETE /api/v1/device/playlists (+ /sync)          │
│      -> Full two-way playlist CRUD mirrored instantly to Customer & Panel  │
│  • POST /api/v1/device/events/token + GET /api/v1/device/events            │
│      -> Real-time SSE push for playlist changes & instant license unlock   │
└──────────────────────────┬───────────────────────────┬─────────────────────┘
                           ▼                           ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────────┐
│ QR #1: Customer Playlists Portal     │  │ QR #2: Activation & Checkout     │
│ /customer/login?mac=...&key=...      │  │ /activate?mac=...&key=...        │
│ -> Auto-login -> /me/playlists       │  │ -> Auto-prefill & lookup device  │
│ -> Add/Edit/Delete -> SSE to Player  │  │ -> Pay -> Instant SSE Unlock     │
└──────────────────────────────────────┘  └──────────────────────────────────┘
```

### Data Model & State

- **Device Entitlement & Anti-Bypass State**:
  - Persists `macNormalized`, `hardwareFingerprint`, `key6`, hashed `credential`, `status` (`trial`, `active`, `expired`, `suspended`, `decommissioned`), `plan` (`TRIAL`, `MONTH_1`, `MONTH_3`, `MONTH_6`, `YEAR_1`, `FOREVER`), `trialEndsAt`, `expiresAt`, and `configVersion`.
  - Every device read/sync evaluates live expiration against server UTC time and computes `accessAllowed`, `trialRemainingDays`, `expiredMessage`, `portalPlaylistsUrl`, and `activateUrl`.
- **Unified Playlist Record (App ↔ Portal ↔ Panel)**:
  - Stores server `id`, optional client `localId`, `name`, `type` (`m3u` or `xtream`), normalized URL/host, Xtream `username`/`password`, `ownerType` (`customer` or `reseller`), `lockedByReseller`, and `version`.
  - Any create, edit, or delete from the app, Customer Portal, or Reseller Panel updates the same server record, increments `configVersion`, and triggers `device.configuration.changed`.

### Interactive Component & State Mapping

- **Yestream Backend Enhancements**:
  - Upgrade device registration to match `hardwareFingerprint` first (recovering original MAC, 6-digit Key, and trial state on app reinstall) and auto-compute/persist `expired` status whenever `expiresAt` has elapsed.
  - Add missing `GET /api/v1/device/playlists` and `PATCH /api/v1/device/playlists/:id` endpoints so the app has complete REST CRUD matching Customer Portal & Reseller Panel.
  - Add `POST /api/v1/device/events/token` and support short-lived event tokens on `GET /api/v1/device/events` for real-time reload & instant unlock on all platforms.
  - Update OpenAPI specification to document all Device API routes and response fields accurately.
- **Yestream Web QR Deep-Links**:
  - Enhance `/activate` to read `?mac=...&key=...` from the QR URL, pre-fill both fields, clean the browser address bar, and automatically run device lookup ready for plan selection and payment.
  - Polish `/me/playlists` with a clear linked-device sync banner confirming that changes immediately push to the player.
- **Deliverable Markdown AI Handoff Specification**:
  - Deliver a comprehensive, copy-paste-ready Markdown document in the workspace containing:
    1. Exact **Virtual MAC + Hardware Fingerprint + 6-Digit Key** algorithms for Electron (Windows/macOS/Linux), Web/PWA, Android, iOS, and Smart TVs — guaranteeing reinstall persistence and zero trial bypass.
    2. Complete **Dynamic Trial & Hard Expiry Lock Screen** specification (`trialDays` from Super Admin, server-time `accessAllowed` check, blocked playback UI with `https://yestream.ai.studio/activate` + QR code, and auto-unlock on activation).
    3. Exact **IPTVnator Backend Deletion Checklist** (what to delete from `apps/web-backend` and configs vs. what to preserve in the player core so nothing crashes).
    4. Full **Yestream Device API Reference** (endpoints, headers, request/response JSON, error codes, two-way Playlist CRUD & SSE reload architecture, and reseller-lock UI rules) ready to hand straight to your other AI.

### Security & Reliability Safeguards

- **Strict Bearer Authentication & Short-Lived Event Tokens**: Device API routes verify the hashed `Authorization: Bearer` credential on every call (removing unverified device-ID-only fallback access), while browser SSE streams use short-lived single-purpose tokens so long-lived credentials never appear in URLs or logs.
- **Environment-Backed Signing & URL Validation**: Offline entitlement signatures use a server-side environment secret with a safe runtime fallback, and all playlist URLs submitted from devices or portals are validated to block private/loopback network targets.
- **Cross-Platform CORS Hygiene**: API CORS headers cleanly handle Electron, Mobile WebView, Smart TV, and Web origins without conflicting wildcard-plus-credentials headers that browsers reject.
