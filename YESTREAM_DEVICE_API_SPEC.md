# Yestream Cloud Device API Specification (Cross-Platform)

Official REST API contract for all Yestream client player platforms:
- **Apple TV (tvOS)**
- **Android TV / Fire TV**
- **Roku Channel**
- **Web / PWA**
- **Desktop (Electron: macOS, Windows, Linux)**

---

## 1. Authentication & Security

All `/api/v1/device/*` endpoints require device authentication via Bearer token:
```http
Authorization: Bearer <deviceCredential>
x-device-id: <deviceId>   (Optional, recommended)
```
- `<deviceCredential>`: Received upon registration (`POST /api/v1/devices/register`), starts with `devsec_...`.
- If an endpoint returns `HTTP 401 Unauthorized`, client should re-authenticate with `POST /api/v1/devices/register` using hardware fingerprint & MAC.

---

## 2. Playlist Locking & Permissions Policy (Updated)

> **Important**: All playlist locking logic, lock/unlock controls, and customer edit/delete restrictions have been removed across all services:
> - **Admin Panel**
> - **Reseller Panel**
> - **Customer Portal**
> - **Device APIs**
>
> Customers can view, edit, and delete **ALL** playlists on their device freely from both the web portal and any player app.
> Deletion removes the playlist immediately and permanently from both Cloud SQL and the administrative panels.

---

## 3. Endpoints Reference

### 3.1 Read / Pull Playlists & Entitlement
```http
GET /api/v1/device/sync
```
Alternative: `GET /api/v1/device/configuration`

**Response (`200 OK`)**:
```json
{
  "serverTime": "2026-11-25T22:58:45.937Z",
  "status": "active",
  "accessAllowed": true,
  "remainingDays": 372,
  "portalLoginUrl": "https://yestream.ai.studio/customer/login?mac=...&key=...",
  "activateUrl": "https://yestream.ai.studio/activate?mac=...&key=...",
  "device": {
    "id": "dev_d5bf39d1a7cd5fd9",
    "mac": "DA:E5:4A:7C:18:3F",
    "status": "active",
    "plan": "YEAR_1",
    "expiresAt": "2027-12-02T21:28:02.807Z"
  },
  "playlists": [
    {
      "id": "pl_d25762a3a7b8927b",
      "localId": null,
      "name": "rev",
      "type": "xtream",
      "url": "http://example.com/get.php?username=...&password=...",
      "host": "http://example.com",
      "username": "H39KM2MOHAMED",
      "password": "...",
      "ownerType": "customer",
      "lockedByReseller": false,
      "version": 2
    }
  ]
}
```

---

### 3.2 Add Playlist (Create or Upsert)
```http
POST /api/v1/device/playlists
Content-Type: application/json
```
Creates a new playlist, or upserts if matching `id`, `localId`, or `url`.

**Request Body (Xtream Codes API)**:
```json
{
  "name": "My Xtream Provider",
  "type": "xtream",
  "host": "http://provider.tv:8080",
  "username": "username123",
  "password": "secretPassword",
  "url": "http://provider.tv:8080/get.php?username=username123&password=secretPassword&type=m3u_plus"
}
```

**Request Body (M3U Link)**:
```json
{
  "name": "My M3U Stream",
  "type": "m3u",
  "url": "https://example.com/playlist.m3u8"
}
```

**Response (`201 Created` / `200 OK`)**:
```json
{
  "playlist": {
    "id": "pl_fa4b47ae60824f30",
    "name": "My Xtream Provider",
    "type": "xtream",
    "url": "...",
    "version": 1
  },
  "configVersion": 13
}
```

---

### 3.3 Edit Playlist (Partial or Full Update)
```http
PATCH /api/v1/device/playlists/:id
PUT /api/v1/device/playlists/:id
Content-Type: application/json
```
Accepts target `:id` as:
- Cloud ID (e.g. `pl_fa4b47ae60824f30`)
- Remote ID (e.g. `remote_pl_fa4b47ae60824f30`)
- Local client ID (e.g. `local_12345`)

Supports partial updates to:
- `name`: String
- `type`: `"xtream"` | `"m3u"`
- `url`: String
- `host` / `xtreamHost`: String (server base host)
- `username` / `xtreamUser`: String
- `password` / `xtreamPass`: String

**Request Body Example (PATCH)**:
```json
{
  "name": "Updated Provider Name",
  "host": "http://newhost.tv:8080",
  "username": "newUsername",
  "password": "newPassword"
}
```

**Response (`200 OK`)**:
```json
{
  "ok": true,
  "playlist": {
    "id": "pl_fa4b47ae60824f30",
    "name": "Updated Provider Name",
    "version": 2
  },
  "configVersion": 14
}
```

---

### 3.4 Delete Playlist (Immediate & Permanent)
```http
DELETE /api/v1/device/playlists/:id
```
- Accepts target `:id` as cloud ID or local ID.
- **Deletes any playlist** (customer-created or reseller-managed) immediately from both Cloud SQL and all panels.
- Returns `200 OK` on success.

**Response (`200 OK`)**:
```json
{
  "ok": true,
  "configVersion": 15
}
```

---

### 3.5 Bulk Two-Way Sync
```http
POST /api/v1/device/playlists/sync
Content-Type: application/json
```
Syncs an array of client playlists in bulk:
```json
{
  "playlists": [
    {
      "id": "pl_1",
      "name": "Main IPTV",
      "type": "xtream",
      "host": "http://example.com",
      "username": "user",
      "password": "pass"
    }
  ]
}
```

---

## 4. Client Implementation Matrix

| Platform | Read / Pull | Add | Edit (PATCH) | Delete | Auto Sync |
|---|---|---|---|---|---|
| **Apple TV (tvOS)** | `GET /sync` | `POST /playlists` | `PATCH /playlists/:id` | `DELETE /playlists/:id` | Supported |
| **Android TV / Fire TV** | `GET /sync` | `POST /playlists` | `PATCH /playlists/:id` | `DELETE /playlists/:id` | Supported |
| **Roku Channel** | `GET /sync` | `POST /playlists` | `PATCH /playlists/:id` | `DELETE /playlists/:id` | Supported |
| **Web / PWA** | `GET /sync` | `POST /playlists` | `PATCH /playlists/:id` | `DELETE /playlists/:id` | Supported |
| **Desktop (Electron)** | `GET /sync` | `POST /playlists` | `PATCH /playlists/:id` | `DELETE /playlists/:id` | Supported |
