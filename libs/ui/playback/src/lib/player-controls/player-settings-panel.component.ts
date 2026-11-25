import {
    ChangeDetectionStrategy,
    Component,
    ElementRef,
    OnDestroy,
    afterNextRender,
    computed,
    inject,
    input,
    output,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslatePipe } from '@ngx-translate/core';
import type { ControlsMenuSelection } from './controls-menu-selection';
import type { ControlsSettings } from './controls-settings';
import type { ControlsSubtitleSettings } from './controls-subtitle-settings';
import type { PlayerController } from './player-controls.model';
import {
    SettingsRadioDirective,
    SettingsRadioGroupDirective,
} from './settings-radio-group.directive';
import {
    SUBTITLE_COLOR_PRESETS,
    SUBTITLE_DELAY_STEP_SECONDS,
    SUBTITLE_SIZE_PRESETS,
    subtitleDelayLabel,
} from './subtitle-style';

export type PlayerSettingsPanelMode = 'panel' | 'sheet';

let nextPanelId = 0;

/**
 * The settings surface behind the dock's `tune` button: audio, subtitles
 * (tracks, file loading, delay, size and color), quality, speed and aspect
 * ratio in one place. Wide players show it as a right-hand panel beside the
 * video, compact players as a bottom sheet. It only renders state and
 * forwards choices to the collaborators the controls component owns.
 */
@Component({
    selector: 'app-player-settings-panel',
    templateUrl: './player-settings-panel.component.html',
    styleUrl: './player-settings-panel.component.scss',
    imports: [
        MatButtonModule,
        MatIconModule,
        MatTooltipModule,
        SettingsRadioDirective,
        SettingsRadioGroupDirective,
        TranslatePipe,
    ],
    changeDetection: ChangeDetectionStrategy.OnPush,
    host: {
        class: 'player-settings',
        role: 'dialog',
        tabindex: '-1',
        '[class.player-settings--sheet]': 'mode() === "sheet"',
        '[attr.aria-labelledby]': 'headingId("title")',
        '(focusin)': 'focusInside = true',
        '(focusout)': 'onFocusOut($event)',
    },
})
export class PlayerSettingsPanelComponent implements OnDestroy {
    private readonly host: HTMLElement =
        inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
    /** Several players can be mounted at once: heading ids stay unique. */
    private readonly idPrefix = `player-settings-${nextPanelId++}`;
    readonly controller = input.required<PlayerController>();
    readonly settings = input.required<ControlsSettings>();
    readonly selection = input.required<ControlsMenuSelection>();
    readonly subtitleSettings = input.required<ControlsSubtitleSettings>();
    readonly mode = input<PlayerSettingsPanelMode>('panel');
    readonly title = input('');
    readonly closeRequested = output<void>();

    readonly state = computed(() => this.controller().state());
    readonly capabilities = computed(() => this.controller().capabilities());
    readonly groups = computed(() => this.settings().groups());
    readonly defaultAspect = computed(() => this.settings().defaultAspect());

    readonly subtitleSizePresets = SUBTITLE_SIZE_PRESETS;
    readonly subtitleColorPresets = SUBTITLE_COLOR_PRESETS;
    readonly subtitleDelayStep = SUBTITLE_DELAY_STEP_SECONDS;
    readonly subtitleDelayLabel = subtitleDelayLabel;

    /** The control that opened the panel, and whether the keyboard did. */
    private readonly opener = document.activeElement;
    private readonly openedByKeyboard =
        this.opener instanceof HTMLElement &&
        this.opener !== document.body &&
        !!this.opener.closest('.player-controls-host') &&
        matchesFocusVisible(this.opener);
    focusInside = false;
    /** Recorded after render: on destroy the panel is already detached. */
    private controlsHost: Element | null = null;

    constructor() {
        // Keyboard users land inside the dialog; a pointer open leaves focus
        // alone (a focused control would capture Space from the shortcuts).
        afterNextRender(() => {
            this.controlsHost = this.host.closest('.player-controls-host');
            if (this.openedByKeyboard) {
                this.host.focus({ preventScroll: true });
                this.focusInside = this.host.contains(document.activeElement);
            }
        });
    }

    onFocusOut(event: FocusEvent): void {
        const next = event.relatedTarget;
        if (next instanceof Node) {
            this.focusInside = this.host.contains(next);
            return;
        }
        // No related target: focus went to the page, or the panel is being
        // removed with focus inside, which Chromium reports with this event
        // while the panel is still attached. The close destroys the panel in
        // the same task, before this microtask runs, so a removal leaves the
        // flag for ngOnDestroy to act on.
        queueMicrotask(() => {
            this.focusInside =
                this.host.isConnected &&
                this.host.contains(document.activeElement);
        });
    }

    /**
     * Closing with focus inside (Escape, the close button by keyboard)
     * returns it to the `tune` button rather than dropping it on the page.
     * Track focus by flag because the view's DOM is already detached when
     * this hook runs.
     */
    ngOnDestroy(): void {
        if (!this.focusInside) {
            return;
        }
        const controls = this.controlsHost;
        queueMicrotask(() =>
            controls
                ?.querySelector<HTMLElement>('.player-controls__tune')
                ?.focus({ preventScroll: true })
        );
    }

    /** The id of a heading that names the dialog or one of its groups. */
    headingId(name: string): string {
        return `${this.idPrefix}-${name}`;
    }

    searchingSubdl = false;
    subdlSearched = false;
    subdlResults: Array<{ id: string; releaseName: string; language: string; downloadUrl: string }> = [];

    async searchOnlineSubtitles(): Promise<void> {
        this.searchingSubdl = true;
        this.subdlSearched = true;
        this.subdlResults = [];

        // Try to get title from document heading or current media title
        let title = '';
        const titleEl = document.querySelector('.portal-inline-player__title, .portal-detail-header__title, h1, .video-title');
        if (titleEl && titleEl.textContent) {
            title = titleEl.textContent.trim();
        }
        if (!title) {
            // Clean up common IPTV tags: DE ★ Movie Name - 2026 [FHD] -> Movie Name
            title = document.title || 'Movie';
        }
        // Remove prefixes like "DE ★", "EN ★", and trailing "[FHD]"
        const cleanTitle = title.replace(/^[A-Z]{2}\s*★\s*/i, '').replace(/\[.*?\]/g, '').replace(/\(.*?\)/g, '').split('-')[0].trim();

        try {
            const apiKey = 'subdl_Gb_Ujrf8yZqzgDmbnB4rD-ouf4BkMX5OWIFDWn4FzyQ';
            const url = `https://api.subdl.com/api/v1/subtitles?api_key=${apiKey}&film_name=${encodeURIComponent(cleanTitle || title)}&languages=en,fr,ar,es,de,it`;
            const res = await fetch(url);
            const data = await res.json();
            if (data.status && Array.isArray(data.subtitles)) {
                this.subdlResults = data.subtitles.slice(0, 10).map((s: any, idx: number) => ({
                    id: `sub-${idx}`,
                    releaseName: s.release_name || s.name || 'Subtitle',
                    language: s.lang || s.language || 'Unknown',
                    downloadUrl: s.url?.startsWith('http') ? s.url : `https://dl.subdl.com${s.url}`,
                }));
            }
        } catch {
            // Ignore fetch error
        } finally {
            this.searchingSubdl = false;
        }
    }

    async loadSubdlSubtitle(sub: { downloadUrl: string; language: string; releaseName: string }): Promise<void> {
        try {
            // Use fflate to unzip in-memory
            const { unzipSync, strFromU8 } = await import('fflate');
            const res = await fetch(sub.downloadUrl);
            const buffer = await res.arrayBuffer();
            const unzipped = unzipSync(new Uint8Array(buffer));

            let srtText = '';
            for (const filename of Object.keys(unzipped)) {
                if (filename.toLowerCase().endsWith('.srt') || filename.toLowerCase().endsWith('.vtt')) {
                    srtText = strFromU8(unzipped[filename]);
                    break;
                }
            }

            if (srtText) {
                // Find active video element in the document
                const video = document.querySelector('video');
                if (video) {
                    let vtt = srtText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
                    vtt = vtt.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
                    const vttUrl = URL.createObjectURL(new Blob([`WEBVTT\n\n${vtt.trim()}`], { type: 'text/vtt' }));

                    // Remove previous injected tracks
                    const existing = video.querySelectorAll('track.subdl-track');
                    existing.forEach((t) => t.remove());

                    const track = document.createElement('track');
                    track.className = 'subdl-track';
                    track.kind = 'subtitles';
                    track.label = `${sub.language} (SubDL)`;
                    track.srclang = sub.language.toLowerCase().slice(0, 2);
                    track.src = vttUrl;
                    track.default = true;

                    video.appendChild(track);
                    if (track.track) {
                        track.track.mode = 'showing';
                    }
                    this.closeRequested.emit();
                }
            }
        } catch (e) {
            console.error('Failed to load SubDL subtitle', e);
        }
    }

    loadExternalSubtitle(): void {
        if (!this.capabilities().externalSubtitles) {
            return;
        }
        this.selection().externalSubtitle();
    }
}

function matchesFocusVisible(element: Element | null): boolean {
    try {
        return (
            element instanceof HTMLElement && element.matches(':focus-visible')
        );
    } catch {
        return false;
    }
}
