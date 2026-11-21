import type { PhoneSettingsDefaults, PlaybackDraft } from '@iptvnator/tv/util';
/** The playback switches, only when the TV offered them. */
export function playbackValues(
    form: HTMLFormElement,
    values: FormData
): PlaybackDraft {
    if (form.querySelector<HTMLElement>('#playback')?.hidden !== false)
        return {};
    return {
        seriesAutoplay: values.has('seriesAutoplay'),
        playerUpNextCard: values.has('playerUpNextCard'),
    };
}
/** Phone pairing form for layout / EPG / playback — TMDB is always-on. */
export function settingsForm(
    form: HTMLFormElement,
    defaults: PhoneSettingsDefaults
) {
    document.title = 'TV settings · Yestream';
    document.querySelector('h1')!.textContent = 'Your TV. Your preferences.';
    document.querySelector('.intro')!.textContent =
        'Adjust settings here, then confirm on your television.';
    form.innerHTML = `<label>Home layout<select name="layout"><option value="cinema">Кинозал · Cinema</option><option value="shelf">Витрина · Showcase</option></select></label>
        <label class="check"><input type="checkbox" name="epg"> Show programme guide</label>
        <div id="playback" hidden><h2>Playback</h2>
        <label class="check"><input type="checkbox" name="seriesAutoplay"> Autoplay next episode</label>
        <label class="check"><input type="checkbox" name="playerUpNextCard"> "Up next" card</label></div>
        <button type="submit">Send settings to TV</button>
        <p class="note">Changes apply only after confirmation on your TV. This link expires in five minutes. Movie and series artwork use built-in metadata.</p>`;
    (form.elements.namedItem('layout') as HTMLSelectElement).value =
        defaults.layout;
    (form.elements.namedItem('epg') as HTMLInputElement).checked = defaults.epg;
    // A TV from before these switches sends no values and would ignore them.
    const playback = form.querySelector<HTMLElement>('#playback')!;
    playback.hidden =
        defaults.seriesAutoplay === undefined &&
        defaults.playerUpNextCard === undefined;
    for (const field of ['seriesAutoplay', 'playerUpNextCard'] as const) {
        const input = form.elements.namedItem(field) as HTMLInputElement;
        input.checked = defaults[field] !== false;
        input.disabled = playback.hidden;
    }
}
