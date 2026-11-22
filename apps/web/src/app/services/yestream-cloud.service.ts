import { Injectable, signal, computed, inject, Injector } from '@angular/core';
import { Store } from '@ngrx/store';
import { PlaylistActions } from '@iptvnator/m3u-state';
import { Playlist, XTREAM_CONTENT_TYPES } from '@iptvnator/shared/interfaces';
import { normalizePlaylistUrl } from '@iptvnator/shared/m3u-utils';
import { PlaylistsService, DataService } from '@iptvnator/services';
import { firstValueFrom } from 'rxjs';

export const YESTREAM_CLOUD_ORIGIN = 'https://yestream.ai.studio';
const YESTREAM_STORAGE_KEY = 'yestream_device_identity_v1';
const YESTREAM_ID_MAP_KEY = 'yestream_id_mapping_v1';

export interface YestreamCloudPlaylist {
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

export interface YestreamSyncResponse {
    serverTime: string;
    trialDays: number;
    configVersion: number;
    changed?: boolean;
    status?: string;
    plan?: string;
    expiresAt?: string;
    playlists: YestreamCloudPlaylist[];
}

@Injectable({
    providedIn: 'root'
})
export class YestreamCloudService {
    private readonly store = inject(Store);
    private readonly injector = inject(Injector);
    private get playlistsService(): PlaylistsService {
        return this.injector.get(PlaylistsService);
    }
    private get dataService(): DataService {
        return this.injector.get(DataService);
    }

    readonly registration = signal<any>(null);
    readonly loading = signal<boolean>(false);
    readonly syncLoading = signal<boolean>(false);
    readonly error = signal<string | null>(null);
    readonly cloudPlaylists = signal<YestreamCloudPlaylist[]>([]);
    readonly configVersion = signal<number>(0);

    readonly macAddress = computed(() => this.registration()?.mac ?? '');
    readonly deviceKey = computed(() => this.registration()?.key6 ?? this.registration()?.deviceKey ?? '');
    readonly plan = computed(() => this.registration()?.plan ?? 'TRIAL');
    readonly status = computed(() => this.registration()?.status ?? 'trial');
    readonly expiresAt = computed(() => this.registration()?.expiresAt ?? '');
    readonly portalLoginUrl = computed(() => this.registration()?.portalLoginUrl ?? '');

    readonly isExpired = computed(() => {
        const reg = this.registration();
        if (!reg) return false;
        if (reg.status === 'expired' || reg.status === 'suspended') return true;
        if (reg.plan === 'FOREVER' || reg.plan === 'LIFETIME') return false;
        if (reg.expiresAt && reg.serverTime) {
            return Date.parse(reg.expiresAt) <= Date.parse(reg.serverTime);
        }
        return false;
    });

    private idMap: Record<string, string> = {}; // localId -> cloudId

    constructor() {
        this.loadStoredIdentity();
        this.loadIdMap();
        void this.registerDevice();
    }

    private loadStoredIdentity(): void {
        try {
            const raw = localStorage.getItem(YESTREAM_STORAGE_KEY);
            if (raw) {
                const parsed = JSON.parse(raw);
                if (parsed && parsed.mac) {
                    this.registration.set(parsed);
                }
            }
        } catch {
            // ignore
        }
    }

    private saveIdentity(data: any): void {
        this.registration.set(data);
        try {
            localStorage.setItem(YESTREAM_STORAGE_KEY, JSON.stringify(data));
        } catch {
            // ignore
        }
    }

    private loadIdMap(): void {
        try {
            const raw = localStorage.getItem(YESTREAM_ID_MAP_KEY);
            if (raw) {
                this.idMap = JSON.parse(raw) || {};
            }
        } catch {
            this.idMap = {};
        }
    }

    private saveIdMap(): void {
        try {
            localStorage.setItem(YESTREAM_ID_MAP_KEY, JSON.stringify(this.idMap));
        } catch {
            // ignore
        }
    }

    private async sha256Hex(message: string): Promise<string> {
        const msgBuffer = new TextEncoder().encode(message);
        const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    private async getOrCreateHardwareIdentity(forceNew = false): Promise<{ mac: string; fp: string }> {
        let rawId = forceNew ? null : localStorage.getItem('yestream_raw_hardware_id');
        if (!rawId) {
            const screenInfo = `${window.screen.width}x${window.screen.height}x${window.screen.colorDepth}`;
            const navInfo = `${navigator.userAgent}-${navigator.language}-${Date.now()}-${Math.random()}`;
            rawId = `${navInfo}-${screenInfo}`;
            try {
                localStorage.setItem('yestream_raw_hardware_id', rawId);
            } catch {
                // ignore
            }
        }

        const fp = await this.sha256Hex(`yestream-pro-fp:${rawId}`);
        const macHash = await this.sha256Hex(`yestream-pro-mac:${rawId}`);

        const macBytes: number[] = [];
        for (let i = 0; i < 6; i++) {
            macBytes.push(parseInt(macHash.slice(i * 2, i * 2 + 2), 16));
        }
        macBytes[0] = (macBytes[0] & 0xfe) | 0x02;

        const mac = macBytes.map(b => b.toString(16).padStart(2, '0').toUpperCase()).join(':');
        return { mac, fp };
    }

    async registerDevice(forceNewHardware = false): Promise<void> {
        this.loading.set(true);
        this.error.set(null);

        try {
            const stored = forceNewHardware ? null : this.registration();
            let mac: string;
            let fp: string;

            if (stored?.mac && stored?.credential && !forceNewHardware) {
                mac = stored.mac;
                fp = stored.hardwareFingerprint || (await this.getOrCreateHardwareIdentity()).fp;
            } else {
                const hw = await this.getOrCreateHardwareIdentity(forceNewHardware);
                mac = hw.mac;
                fp = hw.fp;
            }

            const payload = {
                mac,
                hardwareFingerprint: fp,
                credential: stored?.credential || undefined,
                platform: 'Web',
                model: 'Browser Client',
                os: navigator.userAgent.includes('Mac') ? 'macOS' : navigator.userAgent.includes('Win') ? 'Windows' : 'Linux',
                appVersion: '0.25.1'
            };

            const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/devices/register`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (!res.ok) {
                const errData = await res.json().catch(() => ({}));
                // If 409 conflict: MAC was registered with another fingerprint, auto-recover by rolling a fresh identity
                if (res.status === 409 && !forceNewHardware) {
                    console.warn('[YestreamCloud] MAC conflict, generating fresh hardware identity...');
                    return await this.registerDevice(true);
                }
                throw new Error(errData.error || `HTTP ${res.status}`);
            }

            const data = await res.json();
            this.saveIdentity({
                ...stored,
                ...data,
                hardwareFingerprint: fp,
                status: data.status || stored?.status,
                plan: data.plan || stored?.plan,
                expiresAt: data.expiresAt || stored?.expiresAt
            });
        } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : String(err);
            this.error.set(msg);
        } finally {
            this.loading.set(false);
        }
    }

    /**
     * Manual reload triggered by user: pulls playlists from Cloud API and synchronizes.
     */
    async syncFromCloud(): Promise<void> {
        let reg = this.registration();
        if (!reg?.credential) {
            await this.registerDevice();
            reg = this.registration();
        }
        if (!reg?.credential) {
            this.syncLoading.set(false);
            return;
        }

        this.syncLoading.set(true);
        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 10000);

            const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/sync`, {
                headers: {
                    'Authorization': `Bearer ${reg.credential}`
                },
                signal: controller.signal
            }).finally(() => clearTimeout(timeoutId));

            if (!res.ok) {
                if (res.status === 401) {
                    console.warn('[YestreamCloud] Credential rejected (401), re-registering...');
                    await this.registerDevice();
                }
                return;
            }

            const data: YestreamSyncResponse = await res.json();
            if (data.status) {
                this.saveIdentity({
                    ...reg,
                    status: data.status,
                    plan: data.plan || reg.plan,
                    expiresAt: data.expiresAt || reg.expiresAt,
                    serverTime: data.serverTime || reg.serverTime
                });
            }

            this.configVersion.set(data.configVersion || 0);
            this.cloudPlaylists.set(data.playlists || []);

            await this.reconcileLocalPlaylists(data.playlists || []);
        } catch (e) {
            console.warn('[YestreamCloud] Sync failed:', e);
        } finally {
            this.syncLoading.set(false);
        }
    }

    private isReconciling = false;

    /**
     * Synchronize cloud playlists into local IndexedDB and NgRx store.
     */
    private async reconcileLocalPlaylists(cloudLists: YestreamCloudPlaylist[]): Promise<void> {
        if (this.isReconciling) return;
        this.isReconciling = true;

        try {
            const current: any[] = (await firstValueFrom(this.playlistsService.getAllPlaylists())) || [];

            for (const item of cloudLists) {
                const normalizedUrl = item.url ? normalizePlaylistUrl(item.url) : '';
                
                // Smart Xtream detection: either type is 'xtream', or URL matches standard Xtream get.php pattern
                const isXtreamPattern = normalizedUrl.includes('get.php') && 
                    (normalizedUrl.includes('username=') || normalizedUrl.includes('user=')) && 
                    (normalizedUrl.includes('password=') || normalizedUrl.includes('pass='));
                const isXtream = item.type === 'xtream' || isXtreamPattern;

                let serverUrl = '';
                let username = '';
                let password = '';
                if (isXtream) {
                    if (item.host) {
                        serverUrl = item.host.startsWith('http') ? item.host : `http://${item.host}`;
                    } else if (normalizedUrl) {
                        try {
                            serverUrl = new URL(normalizedUrl).origin;
                        } catch {
                            // ignore
                        }
                    }
                    if (normalizedUrl) {
                        try {
                            const u = new URL(normalizedUrl);
                            username = item.username || u.searchParams.get('username') || u.searchParams.get('user') || '';
                            password = item.password || u.searchParams.get('password') || u.searchParams.get('pass') || '';
                        } catch {
                            username = item.username || '';
                            password = item.password || '';
                        }
                    } else {
                        username = item.username || '';
                        password = item.password || '';
                    }
                }

                // Check if existing locally by ID, mapped ID, URL, or Xtream connection
                const localMappedId = Object.keys(this.idMap).find(k => this.idMap[k] === item.id);
                const exists = current.find(p =>
                    p._id === item.id ||
                    (localMappedId && p._id === localMappedId) ||
                    (item.url && p.url === item.url) ||
                    (serverUrl && p.serverUrl === serverUrl && username && p.username === username)
                );

                if (!exists) {
                    console.log(`[YestreamCloud] Importing playlist from cloud: ${item.name} (${item.id})`);
                    if (isXtream && serverUrl && username) {
                        const newPlaylist: any = {
                            _id: item.id,
                            title: item.name,
                            filename: item.name,
                            importDate: new Date().toISOString(),
                            updateDate: Date.now(),
                            type: 'xtream',
                            serverUrl,
                            username,
                            password,
                            xtreamContentTypes: [...XTREAM_CONTENT_TYPES], // ['movie', 'live', 'series']
                            autoRefresh: false,
                            ownerType: item.ownerType || 'reseller',
                            lockedByReseller: !!item.lockedByReseller,
                        };
                        this.idMap[item.id] = item.id;
                        this.saveIdMap();
                        await firstValueFrom(this.playlistsService.addPlaylist(newPlaylist));
                    } else {
                        // M3U Playlist: create instantly without blocking cloud sync on massive downloads
                        const newM3u: any = {
                            _id: item.id,
                            title: item.name,
                            filename: item.name,
                            url: normalizedUrl,
                            importDate: new Date().toISOString(),
                            updateDate: Date.now(),
                            type: 'm3u',
                            count: 0,
                            playlist: {
                                header: {},
                                items: []
                            },
                            autoRefresh: false,
                            ownerType: item.ownerType || 'reseller',
                            lockedByReseller: !!item.lockedByReseller,
                        };
                        this.idMap[item.id] = item.id;
                        this.saveIdMap();
                        await firstValueFrom(this.playlistsService.addPlaylist(newM3u));

                        // Non-blocking background channel fetch (timed out after 5s so sync is never delayed)
                        if (normalizedUrl) {
                            void Promise.race([
                                this.dataService.fetchPlaylistDefinition(normalizedUrl),
                                new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
                            ]).then((parsed: any) => {
                                if (parsed?.playlist?.items?.length) {
                                    void firstValueFrom(this.playlistsService.updatePlaylist(item.id, {
                                        ...newM3u,
                                        ...parsed,
                                        _id: item.id,
                                        title: item.name,
                                        filename: item.name
                                    }));
                                }
                            }).catch(() => {
                                // Channels will be fetched when user navigates to the playlist
                            });
                        }
                    }
                } else {
                    // Record ID mapping
                    this.idMap[exists._id] = item.id;
                    this.saveIdMap();
                }
            }

            // Remove locally-imported cloud playlists if deleted on the panel
            const cloudIds = new Set(cloudLists.map(c => c.id));
            for (const p of current) {
                const cloudId = this.idMap[p._id] || (p._id?.startsWith('pl_') ? p._id : null);
                if (cloudId && !cloudIds.has(cloudId)) {
                    console.log(`[YestreamCloud] Removing playlist deleted on cloud panel: ${p.title} (${p._id})`);
                    delete this.idMap[p._id];
                    this.saveIdMap();
                    await firstValueFrom(this.playlistsService.deletePlaylist(p._id));
                    this.store.dispatch(PlaylistActions.playlistRemovalCommitted({ playlistId: p._id }));
                }
            }

            this.store.dispatch(PlaylistActions.loadPlaylists());
        } catch (err) {
            console.error('[YestreamCloud] Reconcile error:', err);
        } finally {
            this.isReconciling = false;
        }
    }

    /**
     * When user adds or edits a playlist inside the app, push it to cloud.
     */
    async pushPlaylistToCloud(playlist: Partial<Playlist>): Promise<void> {
        if (this.isReconciling) {
            // Queue retry after brief reconciliation finishes
            setTimeout(() => void this.pushPlaylistToCloud(playlist), 600);
            return;
        }
        let reg = this.registration();
        if (!reg?.credential) {
            await this.registerDevice();
            reg = this.registration();
        }
        if (!reg?.credential) {
            console.warn('[YestreamCloud] Device registration not ready for cloud push');
            return;
        }

        try {
            const isXtream = !!playlist.serverUrl || (playlist as any).type === 'xtream';
            const localId = playlist._id || `local_${Date.now()}`;
            const cloudId = this.idMap[localId] || (playlist._id?.startsWith('pl_') ? playlist._id : undefined);

            // Don't push local files or raw text that have no remote URL
            if (!isXtream && (!playlist.url || !playlist.url.startsWith('http'))) {
                console.log('[YestreamCloud] Local-only playlist, skipping cloud push');
                return;
            }

            const payload: any = {
                localId,
                name: playlist.title || playlist.filename || 'Untitled Playlist',
                type: isXtream ? 'xtream' : 'm3u'
            };

            if (cloudId) {
                payload.id = cloudId;
            }

            if (isXtream) {
                payload.host = playlist.serverUrl;
                payload.username = playlist.username || '';
                payload.password = playlist.password || '';
                if (playlist.serverUrl && playlist.username && playlist.password) {
                    payload.url = `${playlist.serverUrl}/get.php?username=${encodeURIComponent(playlist.username)}&password=${encodeURIComponent(playlist.password)}&type=m3u_plus`;
                }
            } else {
                payload.url = normalizePlaylistUrl(playlist.url || '');
            }

            const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/playlists`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${reg.credential}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            if (res.ok) {
                const data = await res.json();
                if (data?.playlist?.id) {
                    this.idMap[localId] = data.playlist.id;
                    this.saveIdMap();
                }
                console.log('[YestreamCloud] Playlist pushed to cloud successfully:', data);
            } else {
                console.warn('[YestreamCloud] Cloud push returned status:', res.status);
            }
        } catch (e) {
            console.warn('[YestreamCloud] Push playlist failed:', e);
        }
    }

    /**
     * When user deletes a playlist inside the app, delete it from cloud.
     */
    async deletePlaylistFromCloud(playlistId: string): Promise<void> {
        if (this.isReconciling) {
            setTimeout(() => void this.deletePlaylistFromCloud(playlistId), 600);
            return;
        }
        let reg = this.registration();
        if (!reg?.credential) {
            await this.registerDevice();
            reg = this.registration();
        }
        if (!reg?.credential) return;

        try {
            const targetId = this.idMap[playlistId] ||
                (playlistId.startsWith('pl_') ? playlistId : null) ||
                this.cloudPlaylists().find(p => p.id === playlistId || p.localId === playlistId)?.id;

            if (!targetId) {
                console.log('[YestreamCloud] No cloud ID found for deletion:', playlistId);
                return;
            }

            const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/playlists/${targetId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${reg.credential}`
                }
            });

            if (res.ok) {
                delete this.idMap[playlistId];
                this.saveIdMap();
                console.log('[YestreamCloud] Playlist deleted on cloud:', targetId);
            }
        } catch (e) {
            console.warn('[YestreamCloud] Delete playlist from cloud failed:', e);
        }
    }
}
