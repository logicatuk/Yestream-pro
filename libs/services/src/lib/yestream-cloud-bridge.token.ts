import { InjectionToken } from '@angular/core';
import { Playlist } from '@iptvnator/shared/interfaces';

export interface YestreamCloudBridge {
    pushPlaylistToCloud(playlist: Partial<Playlist>): Promise<void>;
    deletePlaylistFromCloud(playlistId: string): Promise<void>;
}

export const YESTREAM_CLOUD_BRIDGE = new InjectionToken<YestreamCloudBridge>(
    'YESTREAM_CLOUD_BRIDGE'
);
