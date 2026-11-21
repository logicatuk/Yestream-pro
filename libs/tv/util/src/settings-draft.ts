import type { UserData } from './index';
export type SetupPurpose = 'source' | 'settings';
/**
 * Playback switches, same names and defaults as desktop. Optional so a TV and
 * a backend from different releases still pair: a missing value keeps what
 * the TV has.
 */
export interface PlaybackDraft {
    seriesAutoplay?: boolean;
    playerUpNextCard?: boolean;
}
export interface SettingsDraft extends PlaybackDraft {
    layout: 'cinema' | 'shelf';
    epg: boolean;
}
export interface PhoneSettingsDefaults extends PlaybackDraft {
    layout: 'cinema' | 'shelf';
    epg: boolean;
}
const playbackFields = ['seriesAutoplay', 'playerUpNextCard'] as const;
export function parseSettingsDraft(value: unknown): SettingsDraft {
    const raw = value as SettingsDraft | undefined;
    if (
        !raw ||
        !['cinema', 'shelf'].includes(raw.layout) ||
        typeof raw.epg !== 'boolean' ||
        playbackFields.some(
            (field) =>
                raw[field] !== undefined && typeof raw[field] !== 'boolean'
        )
    )
        throw new Error('Check the TV settings fields.');
    return {
        layout: raw.layout,
        epg: raw.epg,
        ...playbackDraft(raw),
    };
}
/** Only the playback switches that are present, checked by the caller. */
export function playbackDraft(value: PlaybackDraft): PlaybackDraft {
    const draft: PlaybackDraft = {};
    for (const field of playbackFields)
        if (typeof value[field] === 'boolean') draft[field] = value[field];
    return draft;
}
export function phoneSettingsDefaults(
    data: Pick<
        UserData,
        'layout' | 'epg' | 'seriesAutoplay' | 'playerUpNextCard'
    >
): PhoneSettingsDefaults {
    return {
        layout: data.layout,
        epg: data.epg,
        seriesAutoplay: data.seriesAutoplay,
        playerUpNextCard: data.playerUpNextCard,
    };
}
export function applySettingsDraft(data: UserData, value: unknown): UserData {
    const settings = parseSettingsDraft(value);
    return {
        ...data,
        layout: settings.layout,
        epg: settings.epg,
        seriesAutoplay: settings.seriesAutoplay ?? data.seriesAutoplay,
        playerUpNextCard: settings.playerUpNextCard ?? data.playerUpNextCard,
        // TMDB stays always-on with the bundled key; phone pairing no longer
        // sends API keys or enable toggles.
        tmdb: { ...data.tmdb, enabled: true },
    };
}
