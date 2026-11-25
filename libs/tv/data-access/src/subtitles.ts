import { unzipSync, strFromU8 } from 'fflate';

export const SUBDL_API_KEY = 'subdl_Gb_Ujrf8yZqzgDmbnB4rD-ouf4BkMX5OWIFDWn4FzyQ';
const SUBDL_BASE_URL = 'https://api.subdl.com/api/v1/subtitles';
const SUBDL_DL_BASE = 'https://dl.subdl.com';

export interface OnlineSubtitle {
    id: string;
    releaseName: string;
    language: string;
    langCode: string;
    downloadUrl: string;
    author?: string;
    hearingImpaired?: boolean;
}

export interface SubtitleSearchParams {
    filmName?: string;
    imdbId?: string;
    tmdbId?: number | string;
    type?: 'movie' | 'tv';
    season?: number;
    episode?: number;
    languages?: string; // e.g. "en,fr,ar,es"
}

/** Search subtitles on SubDL API */
export async function searchSubtitles(params: SubtitleSearchParams): Promise<OnlineSubtitle[]> {
    const url = new URL(SUBDL_BASE_URL);
    url.searchParams.set('api_key', SUBDL_API_KEY);
    
    if (params.imdbId) url.searchParams.set('imdb_id', params.imdbId);
    if (params.tmdbId) url.searchParams.set('tmdb_id', String(params.tmdbId));
    if (params.filmName) url.searchParams.set('film_name', params.filmName);
    if (params.type) url.searchParams.set('type', params.type);
    if (params.season) url.searchParams.set('season_number', String(params.season));
    if (params.episode) url.searchParams.set('episode_number', String(params.episode));
    url.searchParams.set('languages', params.languages || 'en,fr,ar,es,de,it');

    try {
        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/json' },
        });
        if (!res.ok) return [];

        const data = await res.json();
        if (!data.status || !Array.isArray(data.subtitles)) return [];

        return data.subtitles.map((item: any, idx: number) => {
            let dl = item.url || '';
            if (dl && !dl.startsWith('http')) {
                dl = `${SUBDL_DL_BASE}${dl}`;
            }
            return {
                id: `subdl-${idx}-${item.url || Math.random()}`,
                releaseName: item.release_name || item.name || 'Subtitle',
                language: item.lang || item.language || 'Unknown',
                langCode: (item.language || item.lang || 'en').toLowerCase(),
                downloadUrl: dl,
                author: item.author,
                hearingImpaired: !!item.hi,
            };
        });
    } catch {
        return [];
    }
}

/** Convert SRT text to standard WebVTT */
export function srtToVtt(srt: string): string {
    // Normalize newlines
    let vtt = srt.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    // Replace comma in timestamps with dot: 00:01:23,456 --> 00:01:23.456
    vtt = vtt.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
    return `WEBVTT\n\n${vtt.trim()}`;
}

/** Fetch zip archive from SubDL, decompress in-memory, and return WebVTT Blob URL */
export async function downloadSubtitleVtt(downloadUrl: string): Promise<string | null> {
    try {
        const res = await fetch(downloadUrl);
        if (!res.ok) return null;

        const buffer = await res.arrayBuffer();
        const unzipped = unzipSync(new Uint8Array(buffer));

        // Find the first .srt file in the archive
        let srtContent = '';
        for (const filename of Object.keys(unzipped)) {
            if (filename.toLowerCase().endsWith('.srt') || filename.toLowerCase().endsWith('.vtt')) {
                srtContent = strFromU8(unzipped[filename]);
                break;
            }
        }

        if (!srtContent) return null;
        const vtt = srtToVtt(srtContent);
        return URL.createObjectURL(new Blob([vtt], { type: 'text/vtt' }));
    } catch {
        return null;
    }
}
