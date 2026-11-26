/** Use the same surface as the inline player's fullscreen control. */
export function openLivePlayerFullscreen(row: HTMLElement): boolean {
    const layout = row.closest(
        'app-video-player, app-live-stream-layout, app-stalker-live-stream-layout, app-unified-live-tab'
    );
    const player = layout?.querySelector<HTMLElement>('app-web-player-view');
    if (!player || typeof player.requestFullscreen !== 'function') return false;
    if (!document.fullscreenElement) {
        void player.requestFullscreen().catch(() => undefined);
    }
    return true;
}
