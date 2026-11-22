import { InjectionToken, Signal } from '@angular/core';
import { Playlist } from '@iptvnator/shared/interfaces';

export interface YestreamCloudBridge {
    pushPlaylistToCloud(playlist: Partial<Playlist>): Promise<void>;
    deletePlaylistFromCloud(playlistId: string): Promise<void>;
    syncFromCloud?(force?: boolean): Promise<any>;
    syncLoading?: Signal<boolean>;
    macAddress?: Signal<string>;
    deviceKey?: Signal<string>;
    plan?: Signal<string>;
    status?: Signal<string>;
    expiresAt?: Signal<string>;
    portalLoginUrl?: Signal<string>;
    isExpired?: Signal<boolean>;
}

export const YESTREAM_CLOUD_BRIDGE = new InjectionToken<YestreamCloudBridge>(
    'YESTREAM_CLOUD_BRIDGE'
);
