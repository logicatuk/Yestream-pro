import { Injectable, signal, computed, inject, Injector } from '@angular/core';
import { Store } from '@ngrx/store';
import { PlaylistActions } from '@iptvnator/m3u-state';
import { Playlist } from '@iptvnator/shared/interfaces';
import { PlaylistsService } from '@iptvnator/services';
import { firstValueFrom } from 'rxjs';

function normalizePlaylistUrl(url: string): string {
    const trimmed = (url || '').trim();
    if (!trimmed) return '';
    try {
        const parsed = new URL(trimmed);
        if (/get\.php/i.test(parsed.pathname)) {
            if (!parsed.searchParams.has('type')) {
                parsed.searchParams.set('type', 'm3u_plus');
            }
            if (!parsed.searchParams.has('output')) {
                parsed.searchParams.set('output', 'ts');
            }
        }
        return parsed.toString();
    } catch {
        return trimmed;
    }
}

export const YESTREAM_CLOUD_ORIGIN = 'https://yestream.ai.studio';
const YESTREAM_STORAGE_KEY = 'yestream_device_identity_v1';

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

    constructor() {
        this.loadStoredIdentity();
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

    private async sha256Hex(message: string): Promise<string> {
        const msgBuffer = new TextEncoder().encode(message);
        const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    private async getOrCreateHardwareIdentity(): Promise<{ mac: string; fp: string }> {
        let rawId = localStorage.getItem('yestream_raw_hardware_id');
        if (!rawId) {
            const screenInfo = `${window.screen.width}x${window.screen.height}x${window.screen.colorDepth}`;
            const navInfo = `${navigator.userAgent}-${navigator.language}-${navigator.hardwareConcurrency || 4}`;
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

    async registerDevice(): Promise<void> {
        this.loading.set(true);
        this.error.set(null);

        try {
            const stored = this.registration();
            let mac: string;
            let fp: string;

            if (stored?.mac && stored?.credential) {
                mac = stored.mac;
                fp = stored.hardwareFingerprint || (await this.getOrCreateHardwareIdentity()).fp;
            } else {
                const hw = await this.getOrCreateHardwareIdentity();
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
        const reg = this.registration();
        if (!reg?.credential) {
            await this.registerDevice();
        }
        const updatedReg = this.registration();
        if (!updatedReg?.credential) return;

        this.syncLoading.set(true);
        try {
            const res = await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/sync`, {
                headers: {
                    'Authorization': `Bearer ${updatedReg.credential}`
                }
            });

            if (!res.ok) return;

            const data: YestreamSyncResponse = await res.json();
            if (data.status) {
                this.saveIdentity({
                    ...updatedReg,
                    status: data.status,
                    plan: data.plan || updatedReg.plan,
                    expiresAt: data.expiresAt || updatedReg.expiresAt,
                    serverTime: data.serverTime || updatedReg.serverTime
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
                const isXtream = item.type === 'xtream' || (normalizedUrl && /get\.php/i.test(normalizedUrl));

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
                    username = item.username || (normalizedUrl ? new URL(normalizedUrl).searchParams.get('username') || '' : '');
                    password = item.password || (normalizedUrl ? new URL(normalizedUrl).searchParams.get('password') || '' : '');
                }

                const exists = current.find(p =>
                    p._id === item.id ||
                    (item.url && p.url === item.url) ||
                    (serverUrl && p.serverUrl === serverUrl && username && p.username === username)
                );

                if (!exists) {
                    console.log(`[YestreamCloud] Importing playlist from cloud: ${item.name} (${item.id})`);
                    const newPlaylist: any = {
                        _id: item.id,
                        title: item.name,
                        filename: item.name,
                        importDate: new Date().toISOString(),
                        updateDate: Date.now(),
                        type: isXtream ? 'xtream' : 'm3u',
                        ownerType: item.ownerType || 'reseller',
                        lockedByReseller: !!item.lockedByReseller,
                    };

                    if (isXtream) {
                        newPlaylist.serverUrl = serverUrl;
                        newPlaylist.username = username;
                        newPlaylist.password = password;
                        newPlaylist.xtreamContentTypes = ['live', 'vod', 'series'];
                    } else {
                        newPlaylist.url = normalizedUrl;
                    }

                    await firstValueFrom(this.playlistsService.addPlaylist(newPlaylist));
                }
            }

            // Remove locally-imported cloud playlists if deleted on the panel
            const cloudIds = new Set(cloudLists.map(c => c.id));
            for (const p of current) {
                if (p._id?.startsWith('pl_') && !cloudIds.has(p._id)) {
                    console.log(`[YestreamCloud] Removing playlist deleted from cloud: ${p.title} (${p._id})`);
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
        if (this.isReconciling) return;
        const reg = this.registration();
        if (!reg?.credential) return;

        try {
            const isXtream = !!playlist.serverUrl;
            const payload: any = {
                localId: playlist._id || `local_${Date.now()}`,
                name: playlist.title || playlist.filename || 'Untitled Playlist',
                type: isXtream ? 'xtream' : 'm3u'
            };

            if (playlist._id?.startsWith('pl_')) {
                payload.id = playlist._id;
            }

            if (isXtream) {
                payload.xtreamHost = playlist.serverUrl;
                payload.xtreamUser = playlist.username || '';
                payload.xtreamPass = playlist.password || '';
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
                console.log('[YestreamCloud] Playlist synced to cloud:', data);
            }
        } catch (e) {
            console.warn('[YestreamCloud] Push playlist failed:', e);
        }
    }

    /**
     * When user deletes a playlist inside the app, delete it from cloud.
     */
    async deletePlaylistFromCloud(playlistId: string): Promise<void> {
        if (this.isReconciling) return;
        const reg = this.registration();
        if (!reg?.credential) return;

        try {
            const cloudItem = this.cloudPlaylists().find(p => p.id === playlistId || p.localId === playlistId);
            const targetId = cloudItem ? cloudItem.id : (playlistId.startsWith('pl_') ? playlistId : null);
            if (!targetId) return;

            await fetch(`${YESTREAM_CLOUD_ORIGIN}/api/v1/device/playlists/${targetId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${reg.credential}`
                }
            });
            console.log('[YestreamCloud] Playlist deleted on cloud:', targetId);
        } catch (e) {
            console.warn('[YestreamCloud] Delete playlist from cloud failed:', e);
        }
    }
}
