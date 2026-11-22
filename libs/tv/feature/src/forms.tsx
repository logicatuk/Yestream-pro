import { useState } from 'preact/hooks';
import {
    httpUrl,
    removeSourceData,
    Source,
    Provider,
} from '@iptvnator/tv/util';
import { TvModel } from './use-tv';

export function Sources({ tv }: { tv: TvModel }) {
    const [type, setType] = useState<Provider>('xtream');
    const [editing, setEditing] = useState<Source>();
    const [failure, setFailure] = useState('');
    const [saving, setSaving] = useState(false);
    function edit(source: Source) {
        setEditing(source);
        setType(source.provider);
    }
    async function submit(event: SubmitEvent) {
        event.preventDefault();
        setFailure('');
        const values = new FormData(event.currentTarget as HTMLFormElement);
        const field = (key: string) => String(values.get(key) ?? '').trim();
        try {
            const source: Source = {
                id:
                    editing?.id ??
                    `tv-${Date.now()}-${Math.random().toString(36).slice(2)}`,
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
        } catch {
            setFailure(
                'Check the URL fields. Use HTTP or HTTPS addresses without embedded login credentials.'
            );
        } finally {
            setSaving(false);
        }
    }
    return (
        <>
            <p class="muted">
                Your subscriptions.
            </p>
            <div class="source-list">
                {tv.data.sources.map((source) => (
                    <div class="source-row" key={source.id}>
                        <button
                            onClick={() => {
                                void tv.switchSource(source.id);
                            }}
                        >
                            {tv.data.activeId === source.id ? '● ' : ''}
                            {source.name}
                        </button>
                        <button
                            disabled={!!source.m3uItems}
                            onClick={() => edit(source)}
                        >
                            {source.m3uItems ? 'Stored playlist' : 'Edit'}
                        </button>
                        <button
                            onClick={() => {
                                if (
                                    confirm(
                                        `Remove ${source.name} and its local viewing data?`
                                    )
                                )
                                    tv.update((d) =>
                                        removeSourceData(d, source.id)
                                    ).catch(() =>
                                        tv.setError('Source was not removed.')
                                    );
                            }}
                        >
                            Remove
                        </button>
                    </div>
                ))}
            </div>
            <div class="filters">
                {(['xtream', 'm3u'] as Provider[]).map((p) => (
                    <button
                        aria-pressed={type === p}
                        onClick={() => {
                            setType(p);
                            setEditing(undefined);
                        }}
                    >
                        {p.toUpperCase()}
                    </button>
                ))}
            </div>
            <form
                class="source-form"
                onSubmit={submit}
                key={`${type}:${editing?.id ?? 'new'}`}
            >
                <h2>{editing ? 'Edit source' : 'Add a source'}</h2>
                <label>
                    Name
                    <input name="name" required defaultValue={editing?.name} />
                </label>
                <label>
                    {type === 'm3u' ? 'Playlist URL' : 'Provider URL'}
                    <input
                        name="url"
                        type="url"
                        required
                        defaultValue={editing?.url}
                        placeholder={type === 'm3u' ? 'https://example.com/playlist.m3u' : 'https://provider.example:port'}
                    />
                </label>
                {type !== 'm3u' ? (
                    <>
                        <label>
                            Username
                            <input
                                name="username"
                                required
                                defaultValue={editing?.username}
                                autoComplete="off"
                            />
                        </label>
                        <label>
                            Password
                            <input
                                name="password"
                                type="password"
                                required
                                defaultValue={editing?.password}
                                autoComplete="off"
                            />
                        </label>
                    </>
                ) : null}
                {failure ? <p role="alert">{failure}</p> : null}
                <button class="primary" disabled={saving}>
                    {saving ? 'Saving…' : 'Save and connect'}
                </button>
            </form>
        </>
    );
}
