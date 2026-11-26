/**
 * Triggers fullscreen on the live player view or underlying video surface.
 * Handles DOM fullscreen across Chromium, Safari, Firefox, and Electron.
 */
export function requestLivePlayerFullscreen(): void {
    if (typeof document === 'undefined') return;
    if (document.fullscreenElement) return;

    const tryFullscreen = (): boolean => {
        if (document.fullscreenElement) return true;
        const target = document.querySelector(
            'app-web-player-view, app-embedded-mpv-player, .video-player, video'
        ) as HTMLElement | null;

        if (target) {
            if (typeof target.requestFullscreen === 'function') {
                void Promise.resolve(target.requestFullscreen()).catch(() => {
                    const video = target.querySelector('video') as
                        | (HTMLVideoElement & { webkitEnterFullscreen?: () => void })
                        | null;
                    if (video) {
                        if (typeof video.requestFullscreen === 'function') {
                            void Promise.resolve(video.requestFullscreen()).catch(
                                () => undefined
                            );
                        } else if (typeof video.webkitEnterFullscreen === 'function') {
                            video.webkitEnterFullscreen();
                        }
                    }
                });
                return true;
            }
        }
        return false;
    };

    if (!tryFullscreen()) {
        requestAnimationFrame(() => {
            if (!tryFullscreen()) {
                setTimeout(tryFullscreen, 120);
            }
        });
    }
}
