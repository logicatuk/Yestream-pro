export const YESTREAM_CLOUD_ORIGIN = 'https://yestream-405211835468.europe-west2.run.app';
const YESTREAM_STORAGE_KEY = 'yestream_device_identity_v1';

export interface TvCloudPlaylist {
    id: string;
    localId?: string | null;
    name: string;
    type: 'm3u' | 'xtream' | 'stalker';
    url?: string;
    host?: string;
    username?: string;
    password?: string;
    ownerType?: string;
    lockedByReseller?: boolean;
    version?: number;
}

export interface TvDeviceRegistration {
    deviceId?: string;
    mac: string;
    key6: string;
    deviceKey: string;
    credential?: string;
    fingerprint: string;
    status: 'trial' | 'active' | 'expired' | 'suspended';
    plan: string;
    expiresAt: string;
    serverTime: string;
    portalLoginUrl: string;
    playlists?: TvCloudPlaylist[];
    configVersion?: number;
    platform?: string;
    model?: string;
    os?: string;
    trialDays?: number;
}

// Compact, bulletproof SHA-256 fallback for Smart TV environments (older webOS / Tizen)
function sha256Pure(ascii: string): string {
    const mathPow = Math.pow;
    const maxWord = mathPow(2, 32);
    const lengthProperty = 'length';
    let i = 0;
    let j = 0;
    let result = '';
    const words: number[] = [];
    const asciiBitLength = ascii[lengthProperty] * 8;
    let hash: number[] = [];
    const k: number[] = [];
    let primeCounter = 0;
    const isComposite: Record<number, number> = {};

    for (let candidate = 2; primeCounter < 64; candidate++) {
        if (!isComposite[candidate]) {
            for (let idx = 0; idx < 313; idx += candidate) {
                isComposite[idx] = candidate;
            }
            hash[primeCounter] = (mathPow(candidate, 0.5) * maxWord) | 0;
            k[primeCounter++] = (mathPow(candidate, 1 / 3) * maxWord) | 0;
        }
    }

    hash = hash.slice(0, 8);
    for (i = 0; i < ascii[lengthProperty]; i++) {
        const charCode = ascii.charCodeAt(i);
        words[i >> 2] |= (charCode & 0xff) << (24 - (i % 4) * 8);
    }
    words[asciiBitLength >> 5] |= 0x80 << (24 - (asciiBitLength % 32));
    words[(((asciiBitLength + 64) >> 9) << 4) + 15] = asciiBitLength;

    const w: number[] = [];
    for (i = 0; i < words[lengthProperty]; i += 16) {
        const oldHash = hash.slice(0);
        for (j = 0; j < 64; j++) {
            let s1: number;
            let ch: number;
            let temp1: number;
            let s0: number;
            let maj: number;
            let temp2: number;
            if (j < 16) {
                w[j] = words[i + j] | 0;
            } else {
                const s0t =
                    ((w[j - 15] >>> 7) | (w[j - 15] << 25)) ^
                    ((w[j - 15] >>> 18) | (w[j - 15] << 14)) ^
                    (w[j - 15] >>> 3);
                const s1t =
                    ((w[j - 2] >>> 17) | (w[j - 2] << 15)) ^
                    ((w[j - 2] >>> 19) | (w[j - 2] << 13)) ^
                    (w[j - 2] >>> 10);
                w[j] = (w[j - 16] + s0t + w[j - 7] + s1t) | 0;
            }
            s1 =
                ((hash[4] >>> 6) | (hash[4] << 26)) ^
                ((hash[4] >>> 11) | (hash[4] << 21)) ^
                ((hash[4] >>> 25) | (hash[4] << 7));
            ch = (hash[4] & hash[5]) ^ (~hash[4] & hash[6]);
            temp1 = (hash[7] + s1 + ch + k[j] + w[j]) | 0;
            s0 =
                ((hash[0] >>> 2) | (hash[0] << 30)) ^
                ((hash[0] >>> 13) | (hash[0] << 19)) ^
                ((hash[0] >>> 22) | (hash[0] << 10));
            maj =
                (hash[0] & hash[1]) ^
                (hash[0] & hash[2]) ^
                (hash[1] & hash[2]);
            temp2 = (s0 + maj) | 0;

            hash[7] = hash[6];
            hash[6] = hash[5];
            hash[5] = hash[4];
            hash[4] = (hash[3] + temp1) | 0;
            hash[3] = hash[2];
            hash[2] = hash[1];
            hash[1] = hash[0];
            hash[0] = (temp1 + temp2) | 0;
        }
        for (j = 0; j < 8; j++) {
            hash[j] = (hash[j] + oldHash[j]) | 0;
        }
    }

    for (i = 0; i < 8; i++) {
        for (j = 3; j >= 0; j--) {
            const byte = (hash[i] >> (j * 8)) & 255;
            result += (byte < 16 ? '0' : '') + byte.toString(16);
        }
    }
    return result;
}

export async function hashSha256(message: string): Promise<string> {
    try {
        if (
            typeof crypto !== 'undefined' &&
            crypto.subtle &&
            typeof crypto.subtle.digest === 'function'
        ) {
            const msgBuffer = new TextEncoder().encode(message);
            const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            return hashArray
                .map((b) => b.toString(16).padStart(2, '0'))
                .join('');
        }
    } catch {
        // Fallback to pure JS
    }
    return sha256Pure(message);
}

export function detectTvPlatform(): {
    platform: string;
    model: string;
    os: string;
    appVersion: string;
} {
    const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
    const appVersion = '0.25.5';

    // LG webOS detection
    const isWebOS = /webOS|web0s|NetCast/i.test(ua) || typeof (window as any)?.webOS !== 'undefined';
    if (isWebOS) {
        const verMatch = ua.match(/web0s\/([0-9.]+)|webOS\/([0-9.]+)/i);
        const ver = verMatch ? verMatch[1] || verMatch[2] : '5.x+';
        return {
            platform: 'LG TV',
            model: `LG Smart TV (webOS ${ver})`,
            os: `webOS ${ver}`,
            appVersion,
        };
    }

    // Samsung Tizen detection
    const isTizen = /Tizen/i.test(ua) || typeof (window as any)?.tizen !== 'undefined';
    if (isTizen) {
        const verMatch = ua.match(/Tizen[ /]([0-9.]+)/i);
        const ver = verMatch ? verMatch[1] : 'Tizen';
        return {
            platform: 'Samsung TV',
            model: `Samsung Smart TV (Tizen ${ver})`,
            os: `Tizen ${ver}`,
            appVersion,
        };
    }

    // Generic TV / Android TV / Web
    if (/Android.*TV|AFTT|AFTM|FireTV/i.test(ua)) {
        return {
            platform: 'Android TV',
            model: 'Smart TV Client',
            os: 'Android TV',
            appVersion,
        };
    }

    return {
        platform: 'Smart TV',
        model: 'Living Room TV',
        os: 'webOS',
        appVersion,
    };
}

export async function getOrCreateTvHardwareIdentity(forceNew = false): Promise<{
    mac: string;
    fingerprint: string;
}> {
    let rawId = forceNew ? '' : '';
    try {
        if (!forceNew) {
            rawId = localStorage.getItem('yestream_raw_hardware_id') || '';
        }
    } catch {
        // ignore
    }

    if (!rawId) {
        const screenInfo =
            typeof window !== 'undefined' && window.screen
                ? `${window.screen.width}x${window.screen.height}x${window.screen.colorDepth}`
                : '1920x1080x24';
        const navInfo = `${typeof navigator !== 'undefined' ? navigator.userAgent : 'tv'}-${Date.now()}-${Math.random()}`;
        rawId = `tv-${navInfo}-${screenInfo}`;
        try {
            localStorage.setItem('yestream_raw_hardware_id', rawId);
        } catch {
            // ignore
        }
    }

    const fingerprint = await hashSha256(`yestream-pro-fp:${rawId}`);
    const macHash = await hashSha256(`yestream-pro-mac:${rawId}`);

    const macBytes: number[] = [];
    for (let i = 0; i < 6; i++) {
        macBytes.push(parseInt(macHash.slice(i * 2, i * 2 + 2), 16));
    }
    // Set locally administered unicast bit
    macBytes[0] = (macBytes[0] & 0xfe) | 0x02;

    const mac = macBytes
        .map((b) => b.toString(16).padStart(2, '0').toUpperCase())
        .join(':');

    return { mac, fingerprint };
}

export function loadStoredTvRegistration(): TvDeviceRegistration | null {
    try {
        const raw = localStorage.getItem(YESTREAM_STORAGE_KEY);
        if (raw) {
            const parsed = JSON.parse(raw);
            if (parsed && parsed.mac) return parsed;
        }
    } catch {
        // ignore
    }
    return null;
}

export function saveStoredTvRegistration(data: TvDeviceRegistration): void {
    try {
        localStorage.setItem(YESTREAM_STORAGE_KEY, JSON.stringify(data));
    } catch {
        // ignore
    }
}

export function buildCustomerLoginUrl(mac: string, key: string): string {
    return `${YESTREAM_CLOUD_ORIGIN}/customer/login?mac=${encodeURIComponent(
        mac
    )}&key=${encodeURIComponent(key)}&redirect=/me/playlists`;
}

/**
 * Registers this TV hardware with Yestream Cloud API (/api/v1/devices/register).
 * Exactly like Web & Android implementation.
 */
export async function registerTvDevice(forceNew = false): Promise<TvDeviceRegistration> {
    const hw = await getOrCreateTvHardwareIdentity(forceNew);
    const platformInfo = detectTvPlatform();
    const stored = forceNew ? null : loadStoredTvRegistration();

    const mac = stored?.mac || hw.mac;
    const fingerprint = stored?.fingerprint || hw.fingerprint;

    const payload = {
        mac,
        hardwareFingerprint: fingerprint,
        credential: stored?.credential || undefined,
        platform: platformInfo.platform,
        model: platformInfo.model,
        os: platformInfo.os,
        appVersion: platformInfo.appVersion,
    };

    try {
        const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/devices/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        if (res.ok) {
            const json = await res.json();
            const key = json.key6 || json.deviceKey || stored?.key6 || '000000';
            const registration: TvDeviceRegistration = {
                deviceId: json.deviceId || stored?.deviceId,
                mac: json.mac || mac,
                key6: key,
                deviceKey: key,
                credential: json.credential || stored?.credential,
                fingerprint: json.hardwareFingerprint || fingerprint,
                status: json.status || 'trial',
                plan: json.plan || 'TRIAL',
                expiresAt: json.expiresAt || json.trialEndsAt || '',
                serverTime: json.serverTime || new Date().toISOString(),
                portalLoginUrl: json.portalLoginUrl || buildCustomerLoginUrl(json.mac || mac, key),
                configVersion: json.configVersion || 1,
                platform: platformInfo.platform,
                model: platformInfo.model,
                os: platformInfo.os,
                trialDays: json.trialDays || 1,
            };
            saveStoredTvRegistration(registration);
            return registration;
        } else if (res.status === 409 && !forceNew) {
            // MAC conflict: regenerate
            return await registerTvDevice(true);
        }
    } catch {
        // Offline or connection error
    }

    if (stored) return stored;

    const fallbackKey = '021845';
    const fallback: TvDeviceRegistration = {
        mac,
        key6: fallbackKey,
        deviceKey: fallbackKey,
        fingerprint,
        status: 'trial',
        plan: 'TRIAL',
        expiresAt: new Date(Date.now() + 86400000).toISOString(),
        serverTime: new Date().toISOString(),
        portalLoginUrl: buildCustomerLoginUrl(mac, fallbackKey),
        configVersion: 1,
        platform: platformInfo.platform,
        model: platformInfo.model,
        os: platformInfo.os,
    };
    saveStoredTvRegistration(fallback);
    return fallback;
}

/**
 * Synchronizes with Yestream Cloud API (/api/v1/device/sync) using Bearer credential.
 * Exactly like Web & Android implementation.
 */
export async function syncTvDevice(
    currentReg: TvDeviceRegistration
): Promise<{ registration: TvDeviceRegistration; playlists: TvCloudPlaylist[] }> {
    let reg = currentReg;
    if (!reg.credential) {
        reg = await registerTvDevice();
    }

    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);

        const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/sync`, {
            method: 'GET',
            headers: {
                Authorization: `Bearer ${reg.credential}`,
            },
            signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (res.ok) {
            const data = await res.json();
            const deviceData = data.device || {};
            const entitlementData = data.entitlement || {};

            const key = deviceData.key6 || deviceData.deviceKey || reg.key6;
            const updatedReg: TvDeviceRegistration = {
                ...reg,
                status: entitlementData.status || deviceData.status || data.status || reg.status,
                plan: entitlementData.plan || deviceData.plan || data.plan || reg.plan,
                expiresAt:
                    entitlementData.expiresAt ||
                    deviceData.expiresAt ||
                    data.expiresAt ||
                    reg.expiresAt,
                serverTime: data.serverTime || new Date().toISOString(),
                configVersion: data.configVersion || reg.configVersion,
                key6: key,
                deviceKey: key,
                portalLoginUrl: deviceData.portalLoginUrl || buildCustomerLoginUrl(reg.mac, key),
            };

            saveStoredTvRegistration(updatedReg);
            return {
                registration: updatedReg,
                playlists: Array.isArray(data.playlists) ? data.playlists : [],
            };
        } else if (res.status === 401) {
            // Re-authenticate
            const refreshed = await registerTvDevice();
            return { registration: refreshed, playlists: [] };
        }
    } catch {
        // Network offline
    }

    return { registration: reg, playlists: [] };
}

export function isTvExpired(registration: TvDeviceRegistration | null): boolean {
    if (!registration) return false;
    if (registration.status === 'expired' || registration.status === 'suspended') {
        return true;
    }
    if (registration.plan === 'FOREVER' || registration.plan === 'LIFETIME') {
        return false;
    }
    if (registration.expiresAt) {
        const expiry = Date.parse(registration.expiresAt);
        const now = registration.serverTime
            ? Date.parse(registration.serverTime)
            : Date.now();
        if (!isNaN(expiry) && expiry <= now) {
            return true;
        }
    }
    return false;
}
