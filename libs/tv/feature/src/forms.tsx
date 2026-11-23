import { useState } from 'preact/hooks';
import { removeSourceData, Source, Provider, httpUrl } from '@iptvnator/tv/util';
import { TvModel } from './use-tv';
import { PlaylistsQuickConnect } from './playlists-quick-connect';
import { AddPlaylistDialog } from './add-playlist-dialog';

/** Playlists screen — split-pane layout.
 *  Left: Quick Connect card (QR + MAC + Key + Portal URL).
 *  Right: Playlist list + [+ Add Playlist] button. */
export function Sources({ tv }: { tv: TvModel }) {
    const [showAdd, setShowAdd] = useState(false);
    const [editing, setEditing] = useState<Source>();
    const [editType, setEditType] = useState<Provider>('xtream');
    const [editFailure, setEditFailure] = useState('');
    const [saving, setSaving] = useState(false);

    function startEdit(source: Source) {
        setEditing(source);
        setEditType(source.provider);
        setEditFailure('');
    }

    function cancelEdit() {
        setEditing(undefined);
        setEditFailure('');
    }

    async function submitEdit(event: SubmitEvent) {
        event.preventDefault();
        setEditFailure('');
        const values = new FormData(event.currentTarget as HTMLFormElement);
        const field = (key: string) => String(values.get(key) ?? '').trim();
        try {
            if (!editing) return;
            const updated: Source = {
                ...editing,
                name: field('name'),
                url: httpUrl(field('url')),
                ...(editType !== 'm3u'
                    ? {
                          username: field('username'),
                          password: field('password'),
                      }
                    : {}),
            };
            setSaving(true);
            await tv.saveSource(updated);
            setEditing(undefined);
        } catch {
            setEditFailure('Check the URL fields. Use HTTP or HTTPS addresses.');
        } finally {
            setSaving(false);
        }
    }

    return (
        <>
            <div class="playlists-screen">
                {/* Left pane — Quick Connect */}
                <div class="playlists-left">
                    {tv.data.backend ? (
                        <PlaylistsQuickConnect tv={tv} />
                    ) : (
                        <div class="playlists-qc playlists-qc--no-backend">
                            <div class="playlists-qc-heading">Quick Connect</div>
                            <p class="muted">
                                Connect to a Yestream backend to unlock QR playlist setup from your phone.
                            </p>
                        </div>
                    )}
                </div>

                {/* Right pane — Playlist list */}
                <div class="playlists-right">
                    <div class="playlists-list">
                        {tv.data.sources.length === 0 ? (
                            <p class="muted playlists-empty">
                                No playlists yet. Add one using the button below or scan the QR code.
                            </p>
                        ) : (
                            tv.data.sources.map((source) => (
                                <div
                                    class={`playlist-row${tv.data.activeId === source.id ? ' playlist-row--active' : ''}`}
                                    key={source.id}
                                >
                                    <button
                                        class="playlist-row-name"
                                        data-focus={`playlist-switch-${source.id}`}
                                        onClick={() => void tv.switchSource(source.id)}
                                    >
                                        <span class="playlist-row-indicator" aria-hidden="true">
                                            {tv.data.activeId === source.id ? '●' : '○'}
                                        </span>
                                        <span class="playlist-row-label">{source.name}</span>
                                        <span class="playlist-row-type">{source.provider.toUpperCase()}</span>
                                    </button>
                                    <div class="playlist-row-actions">
                                        <button
                                            disabled={!!source.m3uItems}
                                            data-focus={`playlist-edit-${source.id}`}
                                            onClick={() => startEdit(source)}
                                            aria-label={`Edit ${source.name}`}
                                        >
                                            {source.m3uItems ? 'Stored' : 'Edit'}
                                        </button>
                                        <button
                                            data-focus={`playlist-remove-${source.id}`}
                                            onClick={() => {
                                                if (
                                                    confirm(
                                                        `Remove ${source.name} and its local viewing data?`
                                                    )
                                                )
                                                    tv.update((d) =>
                                                        removeSourceData(d, source.id)
                                                    ).catch(() =>
                                                        tv.setError('Playlist was not removed.')
                                                    );
                                            }}
                                            aria-label={`Remove ${source.name}`}
                                        >
                                            ✕
                                        </button>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>

                    <div class="playlists-add-row">
                        <button
                            class="primary playlists-add-btn"
                            data-focus="playlists-add"
                            onClick={() => setShowAdd(true)}
                        >
                            + Add Playlist
                        </button>
                    </div>
                </div>
            </div>

            {/* Add Playlist dialog */}
            {showAdd && (
                <AddPlaylistDialog
                    tv={tv}
                    onClose={() => setShowAdd(false)}
                />
            )}

            {/* Edit existing playlist dialog (inline) */}
            {editing && (
                <div class="tv-dialog-backdrop">
                    <div
                        class="tv-dialog add-playlist-dialog"
                        role="dialog"
                        aria-modal={true}
                        aria-label="Edit Playlist"
                    >
                        <div class="tv-dialog-header">
                            <h2>Edit Playlist</h2>
                            <button onClick={cancelEdit}>✕ Cancel</button>
                        </div>
                        <form
                            class="add-playlist-form"
                            onSubmit={submitEdit}
                            key={editing.id}
                        >
                            <label>
                                Playlist name
                                <input
                                    name="name"
                                    required
                                    defaultValue={editing.name}
                                    autoComplete="off"
                                />
                            </label>
                            <label>
                                {editType === 'm3u' ? 'Playlist URL' : 'Provider URL'}
                                <input
                                    name="url"
                                    type="url"
                                    required
                                    defaultValue={editing.url}
                                />
                            </label>
                            {editType !== 'm3u' ? (
                                <>
                                    <label>
                                        Username
                                        <input
                                            name="username"
                                            required
                                            defaultValue={editing.username}
                                            autoComplete="off"
                                        />
                                    </label>
                                    <label>
                                        Password
                                        <input
                                            name="password"
                                            type="password"
                                            required
                                            defaultValue={editing.password}
                                            autoComplete="off"
                                        />
                                    </label>
                                </>
                            ) : null}
                            {editFailure ? (
                                <p role="alert" class="add-playlist-error">{editFailure}</p>
                            ) : null}
                            <div class="add-playlist-actions">
                                <button type="submit" class="primary" disabled={saving}>
                                    {saving ? 'Saving…' : 'Save'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </>
    );
}
