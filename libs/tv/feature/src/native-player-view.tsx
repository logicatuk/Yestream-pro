import { useLayoutEffect, useState, useEffect } from 'preact/hooks';
import { restoreFocus } from '@iptvnator/tv/ui';
import type { RefObject } from 'preact';
import type { VodSequence } from './use-vod-sequence';
import { episodeCode, mediaTitle } from '@iptvnator/tv/util';
import type { TvModel } from './use-tv';
import type { useLiveOverlay } from './live-overlay';
import type { useSeriesDetails } from './use-series-details';
import { UpNextCard, useUpNext } from './up-next-card';
import type { usePlayerControls } from './player-controls';
import { searchSubtitles, downloadSubtitleVtt, OnlineSubtitle } from '@iptvnator/tv/data-access';

export function NativePlayerView({
    tv,
    video,
    controls,
    overlay,
    seriesDetails,
    back,
    openPlaylist,
    vod,
    previousChannel,
}: {
    tv: TvModel;
    video: RefObject<HTMLVideoElement>;
    controls: ReturnType<typeof usePlayerControls>;
    overlay: ReturnType<typeof useLiveOverlay>;
    seriesDetails: ReturnType<typeof useSeriesDetails>;
    back: () => void;
    openPlaylist: () => void;
    vod: VodSequence;
    previousChannel: { play: () => void; pending: boolean };
}) {
    const current = tv.playing;
    const element = video.current;

    // Online Subtitles State
    const [showSubtitles, setShowSubtitles] = useState(false);
    const [searchingSubs, setSearchingSubs] = useState(false);
    const [subtitlesList, setSubtitlesList] = useState<OnlineSubtitle[]>([]);
    const [activeSubId, setActiveSubId] = useState<string>('none');
    const [subOffset, setSubOffset] = useState<number>(0);
    const [downloadingSub, setDownloadingSub] = useState(false);

    // Search subtitles when opening the panel
    useEffect(() => {
        if (!showSubtitles || !current || current.kind === 'live') return;

        let active = true;
        setSearchingSubs(true);
        const title = current.title || (current as any).name || '';

        searchSubtitles({
            filmName: title,
            type: current.kind === 'episode' ? 'tv' : 'movie',
            season: current.season,
            episode: current.episode,
            languages: 'fr,en,ar,es,de,it',
        }).then((subs) => {
            if (!active) return;
            setSubtitlesList(subs);
            setSearchingSubs(false);
        }).catch(() => {
            if (active) setSearchingSubs(false);
        });

        return () => {
            active = false;
        };
    }, [showSubtitles, current]);

    // Apply subtitle track to HTML5 video element
    const selectSubtitle = async (sub: OnlineSubtitle | null) => {
        if (!element) return;

        // Clear existing injected subtitle tracks
        const existingTrack = element.querySelector('track.online-sub');
        if (existingTrack) {
            existingTrack.remove();
        }

        if (!sub) {
            setActiveSubId('none');
            return;
        }

        setDownloadingSub(true);
        try {
            const vttUrl = await downloadSubtitleVtt(sub.downloadUrl);
            if (vttUrl) {
                const track = document.createElement('track');
                track.className = 'online-sub';
                track.kind = 'subtitles';
                track.label = `${sub.language} (SubDL)`;
                track.srclang = sub.langCode;
                track.src = vttUrl;
                track.default = true;

                element.appendChild(track);
                if (track.track) {
                    track.track.mode = 'showing';
                }
                setActiveSubId(sub.id);
            }
        } finally {
            setDownloadingSub(false);
        }
    };
    const upNext = useUpNext(
        tv,
        video,
        vod,
        !!overlay.panel,
        controls.reveal,
        seriesDetails.busy
    );
    useLayoutEffect(() => {
        if (!element?.ended || !vod.next || !tv.fullscreen) return;
        let owns = true;
        restoreFocus('player-next', '', undefined, () => owns);
        return () => {
            owns = false;
        };
    }, [element?.ended, vod.next?.id, tv.fullscreen]);
    const sourceName =
        tv.data.sources.find((source) => source.id === current?.sourceId)
            ?.name ?? 'Source unavailable';
    const time = (seconds: number) =>
        Number.isFinite(seconds)
            ? `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`
            : 'LIVE';
    // Same action as the Play/Pause button: an ended title starts over.
    const togglePlayback = () =>
        element?.ended && current && current.kind !== 'live'
            ? tv.startOver(current)
            : tv.player.current?.toggle();
    // The visible controls layer sits over the video and receives bare picture clicks.
    const clickPicture = (event: MouseEvent) => {
        if (
            !tv.fullscreen ||
            overlay.panel ||
            !(event.target as Element | null)?.matches?.(
                'video, .player-controls'
            )
        )
            return;
        togglePlayback();
    };
    return (
        <div
            class={`native-player ${tv.fullscreen ? 'fullscreen' : 'preview'}`}
            hidden={!current}
            onClick={clickPicture}
        >
            <video ref={video} playsInline preload="metadata" />
            {tv.fullscreen && upNext.card ? (
                <UpNextCard
                    card={upNext.card}
                    collapsed={upNext.collapsed}
                    play={upNext.play}
                />
            ) : null}
            {tv.fullscreen ? (
                <div
                    class={`player-controls ${controls.visible || tv.error ? '' : 'dormant'}`}
                    hidden={!!overlay.panel}
                >
                    <div class="player-top">
                        <button data-focus="player-back" onClick={back}>
                            ← Back
                        </button>
                        {current?.kind === 'live' ? (
                            <div class="actions">
                                {tv.previousChannel ? (
                                    <button
                                        data-focus="player-previous"
                                        disabled={previousChannel.pending}
                                        onClick={previousChannel.play}
                                    >
                                        Previous channel ·{' '}
                                        {tv.previousChannel.title}
                                    </button>
                                ) : null}
                                <button
                                    data-focus="player-channels"
                                    onClick={overlay.openChannels}
                                >
                                    Channels
                                </button>
                                <button
                                    data-focus="player-grid"
                                    onClick={overlay.openGrid}
                                >
                                    TV Guide
                                </button>
                                <button
                                    data-focus="player-guide"
                                    onClick={overlay.openGuide}
                                >
                                    Programme
                                </button>
                            </div>
                        ) : null}
                        <span>
                            {current?.kind === 'live'
                                ? 'LIVE TELEVISION'
                                : 'NOW WATCHING'}
                        </span>
                    </div>
                    <div class="player-bottom">
                        <span class="eyebrow">
                            {current?.season
                                ? `SEASON ${current.season} · EPISODE ${current.episode}`
                                : 'IPTVNATOR TV'}
                        </span>
                        <h1>{current && mediaTitle(current)}</h1>
                        <p class="player-source-name">{sourceName}</p>
                        {current?.kind === 'episode' ? (
                            <p>{current.title}</p>
                        ) : null}
                        {element?.ended && current?.kind === 'episode' ? (
                            <p role="status">
                                Episode finished.{' '}
                                {vod.next
                                    ? vod.activating
                                        ? 'Playing the next episode…'
                                        : 'Choose Next episode to continue.'
                                    : vod.busy
                                      ? 'Finding the next episode…'
                                      : vod.failed
                                        ? 'Next episode is unavailable.'
                                        : 'No next episode was supplied.'}
                            </p>
                        ) : null}
                        {current?.kind === 'episode' && vod.failed ? (
                            <button onClick={vod.retry}>
                                Retry next episode
                            </button>
                        ) : null}
                        <div class="actions">
                            {vod.next ? (
                                <button
                                    class={element?.ended ? 'primary' : ''}
                                    data-focus="player-next"
                                    disabled={vod.activating}
                                    onClick={() => void vod.playNext()}
                                >
                                    Next episode · {episodeCode(vod.next)} →
                                </button>
                            ) : null}
                            <button
                                data-focus="player-toggle"
                                class="primary"
                                onClick={togglePlayback}
                            >
                                {element?.ended && current?.kind !== 'live'
                                    ? 'Watch again ▶'
                                    : element?.paused
                                      ? 'Play ▶'
                                      : 'Pause Ⅱ'}
                            </button>
                            {current?.kind === 'episode' ? (
                                <button
                                    data-focus="player-series-details"
                                    disabled={seriesDetails.busy}
                                    onClick={() =>
                                        void seriesDetails.open(current)
                                    }
                                >
                                    {seriesDetails.busy
                                        ? 'Finding series…'
                                        : 'Series details →'}
                                </button>
                            ) : null}
                            {current?.kind !== 'live' ? (
                                <>
                                    <button
                                        onClick={() =>
                                            tv.player.current?.seek(-10)
                                        }
                                    >
                                        −10 sec
                                    </button>
                                    <button
                                        onClick={() =>
                                            tv.player.current?.seek(10)
                                        }
                                    >
                                        +10 sec
                                    </button>
                                    <span>
                                        {time(element?.currentTime ?? 0)} /{' '}
                                        {time(element?.duration ?? 0)}
                                    </span>
                                    <button
                                        class={`tv-toggle ${activeSubId !== 'none' ? 'primary' : ''}`}
                                        data-focus="player-subtitles"
                                        onClick={() => setShowSubtitles((s) => !s)}
                                    >
                                        💬 {activeSubId !== 'none' ? 'Subtitles (On)' : 'Subtitles'}
                                    </button>
                                </>
                            ) : null}
                            {current?.kind === 'live' ? (
                                <button
                                    data-focus="player-playlist"
                                    onClick={openPlaylist}
                                >
                                    Go to playlist
                                </button>
                            ) : null}
                            <button
                                class="tv-toggle"
                                aria-pressed={tv.data.favorites.some(
                                    (item) => item.id === current?.id
                                )}
                                onClick={() => current && tv.favorite(current)}
                            >
                                {tv.data.favorites.some(
                                    (item) => item.id === current?.id
                                )
                                    ? '♥ Saved'
                                    : '♡ Save'}
                            </button>
                        </div>
                        {current?.kind !== 'live' ? (
                            <label class="seek">
                                Playback position
                                <input
                                    aria-label="Playback position"
                                    type="range"
                                    min="0"
                                    max={
                                        Number.isFinite(element?.duration)
                                            ? (element?.duration ?? 0)
                                            : 0
                                    }
                                    value={element?.currentTime ?? 0}
                                    onInput={(e) => {
                                        tv.player.current?.seekTo(
                                            Number(e.currentTarget.value)
                                        );
                                    }}
                                />
                            </label>
                        ) : null}
                        {tv.player.current?.restoringPosition ? (
                            <p role="status">Restoring saved position…</p>
                        ) : null}
                        {tv.error ? (
                            <div role="alert" class="error">
                                {tv.error}
                                {tv.errorRetry ? (
                                    <button onClick={tv.errorRetry}>
                                        {tv.errorRetryLabel}
                                    </button>
                                ) : null}
                                <button onClick={() => tv.setError('')}>
                                    Dismiss
                                </button>
                            </div>
                        ) : null}
                    </div>
                </div>
            ) : null}

            {/* Subtitle Selection Drawer Overlay */}
            {showSubtitles && tv.fullscreen ? (
                <div class="player-subtitles-drawer">
                    <div class="subtitles-header">
                        <div class="subtitles-title-box">
                            <span class="subtitles-badge">SUBDL ONLINE ENGINE</span>
                            <h2>Subtitles &amp; Captions</h2>
                        </div>
                        <button
                            class="subtitles-close-btn"
                            onClick={() => setShowSubtitles(false)}
                        >
                            ✕
                        </button>
                    </div>

                    <div class="subtitles-sync-bar">
                        <span class="sync-label">Sync Offset:</span>
                        <button
                            class="sync-btn"
                            onClick={() => {
                                setSubOffset((o) => o - 0.5);
                                if (element && element.textTracks[0]) {
                                    // Offset adjustments
                                }
                            }}
                        >
                            ◄ -0.5s
                        </button>
                        <span class="sync-value">{subOffset > 0 ? `+${subOffset.toFixed(1)}s` : `${subOffset.toFixed(1)}s`}</span>
                        <button
                            class="sync-btn"
                            onClick={() => {
                                setSubOffset((o) => o + 0.5);
                            }}
                        >
                            +0.5s ►
                        </button>
                    </div>

                    <div class="subtitles-list">
                        <div
                            class={`subtitle-item ${activeSubId === 'none' ? 'selected' : ''}`}
                            onClick={() => void selectSubtitle(null)}
                            tabIndex={0}
                            onKeyDown={(e: any) => { if (e.key === 'Enter') void selectSubtitle(null); }}
                        >
                            <span class="sub-radio">{activeSubId === 'none' ? '●' : '○'}</span>
                            <span class="sub-title">Off (No Subtitles)</span>
                        </div>

                        {searchingSubs ? (
                            <div class="subtitles-loading">
                                <span>Searching SubDL online database…</span>
                            </div>
                        ) : null}

                        {downloadingSub ? (
                            <div class="subtitles-loading downloading">
                                <span>Downloading &amp; syncing subtitle…</span>
                            </div>
                        ) : null}

                        {!searchingSubs && subtitlesList.length === 0 ? (
                            <div class="subtitles-empty">
                                <span>No online subtitles found for this title.</span>
                            </div>
                        ) : null}

                        {subtitlesList.map((sub) => {
                            const isSelected = activeSubId === sub.id;
                            return (
                                <div
                                    class={`subtitle-item ${isSelected ? 'selected' : ''}`}
                                    key={sub.id}
                                    onClick={() => void selectSubtitle(sub)}
                                    tabIndex={0}
                                    onKeyDown={(e: any) => { if (e.key === 'Enter') void selectSubtitle(sub); }}
                                >
                                    <span class="sub-radio">{isSelected ? '●' : '○'}</span>
                                    <div class="sub-info">
                                        <div class="sub-lang-row">
                                            <span class="sub-lang">{sub.language}</span>
                                            {sub.hearingImpaired ? <span class="sub-tag">CC</span> : null}
                                        </div>
                                        <span class="sub-release">{sub.releaseName}</span>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>
            ) : null}
        </div>
    );
}
