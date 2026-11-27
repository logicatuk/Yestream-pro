import { tr } from '@iptvnator/tv/ui';
import { useState, useRef, useLayoutEffect } from 'preact/hooks';
import { httpUrl, removeSourceData, Source, Provider } from '@iptvnator/tv/util';
import { isBackKey } from '@iptvnator/tv/util';
import { TvModel } from './use-tv';

/** Modal dialog for adding a new playlist.
 *  Two tabs: M3U URL | Xtream Codes.
 *  Fully D-pad navigable. Back key cancels. */
export function AddPlaylistDialog({
    tv,
    onClose,
}: {
    tv: TvModel;
    onClose: () => void;
}) {
    const [type, setType] = useState<Provider>('xtream');
    const [failure, setFailure] = useState('');
    const [saving, setSaving] = useState(false);
    const dialogRef = useRef<HTMLDivElement>(null);

    // Focus first interactive element when dialog opens
    useLayoutEffect(() => {
        const first = dialogRef.current?.querySelector<HTMLElement>(
            'button:not(:disabled), input, select'
        );
        first?.focus();
    }, []);

    async function submit(event: SubmitEvent) {
        event.preventDefault();
        setFailure('');
        const values = new FormData(event.currentTarget as HTMLFormElement);
        const field = (key: string) => String(values.get(key) ?? '').trim();
        try {
            const source: Source = {
                id: `tv-${Date.now()}-${Math.random().toString(36).slice(2)}`,
                name: field('name'),
                provider: type,
                url: httpUrl(field('url')),
                ...(type !== 'm3u'
                    ? {
                          username: field('username'),
                          password: field('password'),
                      }
                    : {}),
            };
            setSaving(true);
            await tv.saveSource(source);
            onClose();
        } catch {
            setFailure(
                'Check the URL fields. Use HTTP or HTTPS addresses without embedded credentials.'
            );
        } finally {
            setSaving(false);
        }
    }

    return (
        <div
            class="tv-dialog-backdrop"
            onKeyDown={(event) => {
                if (isBackKey(event)) {
                    event.preventDefault();
                    event.stopPropagation();
                    onClose();
                }
            }}
        >
            <div
                ref={dialogRef}
                class="tv-dialog add-playlist-dialog"
                role="dialog"
                aria-modal={true}
                aria-label="Add Playlist"
            >
                <div class="tv-dialog-header">
                    <h2>Add Playlist</h2>
                    <button
                        data-focus="add-playlist-cancel"
                        onClick={onClose}
                        aria-label={tr("Cancel")}
                    >
                        ✕ Cancel
                    </button>
                </div>

                {/* Type tabs */}
                <div class="add-playlist-tabs" role="tablist" aria-label="Playlist type">
                    {(['xtream', 'm3u'] as Provider[]).map((p) => (
                        <button
                            key={p}
                            role="tab"
                            aria-selected={type === p}
                            data-focus={`add-playlist-tab-${p}`}
                            class={`add-playlist-tab${type === p ? ' active' : ''}`}
                            onClick={() => {
                                setType(p);
                                setFailure('');
                            }}
                        >
                            {p === 'm3u' ? 'M3U URL' : 'Xtream Codes'}
                        </button>
                    ))}
                </div>

                <form
                    class="add-playlist-form"
                    onSubmit={submit}
                    key={type}
                >
                    <label>
                        Playlist name
                        <input
                            name="name"
                            required
                            data-focus="add-playlist-name"
                            placeholder="My IPTV"
                            autoComplete="off"
                        />
                    </label>

                    <label>
                        {type === 'm3u' ? 'Playlist URL' : 'Provider URL'}
                        <input
                            name="url"
                            type="url"
                            required
                            data-focus="add-playlist-url"
                            placeholder={
                                type === 'm3u'
                                    ? 'https://example.com/playlist.m3u'
                                    : 'https://provider.example:8080'
                            }
                        />
                    </label>

                    {type !== 'm3u' ? (
                        <>
                            <label>{tr("Username")}<input
                                    name="username"
                                    required
                                    data-focus="add-playlist-user"
                                    autoComplete="off"
                                />
                            </label>
                            <label>{tr("Password")}<input
                                    name="password"
                                    type="password"
                                    required
                                    data-focus="add-playlist-pass"
                                    autoComplete="off"
                                />
                            </label>
                        </>
                    ) : null}

                    {failure ? (
                        <p role="alert" class="add-playlist-error">
                            {failure}
                        </p>
                    ) : null}

                    <div class="add-playlist-actions">
                        <button
                            type="submit"
                            class="primary"
                            disabled={saving}
                            data-focus="add-playlist-save"
                        >
                            {saving ? 'Saving…' : 'Save & Connect'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}
