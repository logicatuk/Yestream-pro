import { tr } from '@iptvnator/tv/ui';
import { useState, useEffect } from 'preact/hooks';
import QRCode from 'qrcode';
import {
    httpUrl,
    removeSourceData,
    Source,
    Provider,
} from '@iptvnator/tv/util';
import {
    registerTvDevice,
    syncTvDevice,
    deleteTvCloudPlaylist,
    loadStoredTvRegistration,
    TvDeviceRegistration,
    YESTREAM_CLOUD_ORIGIN,
    buildCustomerLoginUrl,
} from '@iptvnator/tv/data-access';
import { TvModel } from './use-tv';

export function Sources({ tv }: { tv: TvModel }) {
    const [registration, setRegistration] = useState<TvDeviceRegistration | null>(
        loadStoredTvRegistration()
    );
    const [qrDataUrl, setQrDataUrl] = useState<string>('');
    const [syncing, setSyncing] = useState<boolean>(false);
    const [syncMsg, setSyncMsg] = useState<string>('');

    // Add / Edit Dialog state
    const [showDialog, setShowDialog] = useState<boolean>(false);
    const [type, setType] = useState<Provider>('xtream');
    const [editing, setEditing] = useState<Source>();
    const [failure, setFailure] = useState('');
    const [saving, setSaving] = useState(false);

    // Initial registration & QR generation
    useEffect(() => {
        let mounted = true;
        void registerTvDevice().then(async (reg) => {
            if (!mounted) return;
            setRegistration(reg);
            const portalUrl =
                reg.portalLoginUrl ||
                buildCustomerLoginUrl(reg.mac, reg.key6 || reg.deviceKey);
            try {
                const qr = await QRCode.toDataURL(portalUrl, {
                    width: 240,
                    margin: 2,
                    errorCorrectionLevel: 'M',
                    color: { dark: '#0b1329', light: '#ffffff' },
                });
                if (mounted) setQrDataUrl(qr);
            } catch {
                // ignore
            }
        });
        return () => {
            mounted = false;
        };
    }, []);

    async function handleSyncCloud() {
        if (!registration || syncing) return;
        setSyncing(true);
        setSyncMsg('Syncing with Yestream Cloud…');
        try {
            const { registration: updated, playlists } = await syncTvDevice(registration);
            setRegistration(updated);
            if (playlists && playlists.length > 0) {
                let syncedCount = 0;
                let firstSyncedId = '';

                for (const cp of playlists) {
                    const isXtream = cp.type === 'xtream' || (cp.url && cp.url.includes('get.php'));
                    let serverUrl = '';
                    let username = cp.username || '';
                    let password = cp.password || '';

                    if (isXtream) {
                        if (cp.host) {
                            serverUrl = cp.host.startsWith('http') ? cp.host : `http://${cp.host}`;
                        } else if (cp.url) {
                            try {
                                serverUrl = new URL(cp.url).origin;
                            } catch {
                                serverUrl = cp.url;
                            }
                        }
                        if (cp.url) {
                            try {
                                const u = new URL(cp.url);
                                username = username || u.searchParams.get('username') || u.searchParams.get('user') || '';
                                password = password || u.searchParams.get('password') || u.searchParams.get('pass') || '';
                            } catch {
                                // ignore
                            }
                        }
                    } else {
                        serverUrl = cp.url || '';
                    }

                    if (!serverUrl) continue;
                    if (!/^https?:\/\//i.test(serverUrl)) {
                        serverUrl = `http://${serverUrl}`;
                    }

                    const sourceId = cp.id || `cloud-${Date.now()}`;
                    const newSource: Source = {
                        id: sourceId,
                        name: cp.name || 'Cloud Playlist',
                        provider: (isXtream ? 'xtream' : 'm3u') as Provider,
                        url: serverUrl,
                        ...(isXtream ? { username, password } : {}),
                    };

                    const existing = tv.data.sources.find((s) => s.id === cp.id || s.name === cp.name);
                    if (existing) {
                        await tv.update((d) => ({
                            ...d,
                            sources: d.sources.map((s) => s.id === existing.id ? { ...s, ...newSource, id: existing.id } : s),
                            activeId: d.activeId || existing.id,
                        }));
                        if (!firstSyncedId) firstSyncedId = existing.id;
                    } else {
                        await tv.update((d) => ({
                            ...d,
                            sources: [...d.sources, newSource],
                            activeId: d.activeId || newSource.id,
                        }));
                        if (!firstSyncedId) firstSyncedId = newSource.id;
                    }
                    syncedCount++;
                }

                if (firstSyncedId && !tv.data.activeId) {
                    void tv.switchSource(firstSyncedId);
                }
                setSyncMsg(`Synced! ${syncedCount} playlist(s) connected and ready.`);
            } else {
                setSyncMsg('Device synced. No new cloud playlists.');
            }
        } catch (e: any) {
            setSyncMsg(`Sync error: ${e?.message || 'Check network connection'}`);
        } finally {
            setSyncing(false);
            setTimeout(() => setSyncMsg(''), 5000);
        }
    }

    function openAddModal() {
        setEditing(undefined);
        setType('xtream');
        setFailure('');
        setShowDialog(true);
    }

    function openEditModal(source: Source) {
        setEditing(source);
        setType(source.provider);
        setFailure('');
        setShowDialog(true);
    }

    async function submit(event: SubmitEvent) {
        event.preventDefault();
        setFailure('');
        const values = new FormData(event.currentTarget as HTMLFormElement);
        const field = (key: string) => String(values.get(key) ?? '').trim();
        try {
            let rawUrl = field('url');
            if (!rawUrl) throw new Error('Please enter a server or playlist URL');
            if (!/^https?:\/\//i.test(rawUrl)) {
                rawUrl = `http://${rawUrl}`;
            }

            const sourceId =
                editing?.id ??
                `tv-${Date.now()}-${Math.random().toString(36).slice(2)}`;
            const name = field('name') || (type === 'xtream' ? 'Xtream Service' : 'M3U Playlist');

            const source: Source = {
                id: sourceId,
                name,
                provider: type,
                url: httpUrl(rawUrl),
                ...(type !== 'm3u'
                    ? {
                        username: field('username'),
                        password: field('password'),
                    }
                    : {}),
            };
            setSaving(true);
            await tv.saveSource(source);
            setShowDialog(false);
        } catch (err: any) {
            setFailure(
                err?.message ||
                'Invalid URL. Please enter a valid HTTP or HTTPS address.'
            );
        } finally {
            setSaving(false);
        }
    }

    const mac = registration?.mac || '36:C2:EF:41:0C:7C';
    const key = registration?.key6 || registration?.deviceKey || '466761';
    const status = registration?.status || 'active';
    const plan = registration?.plan || 'YEAR_1';

    return (
        <div class="playlists-screen">
            {/* Split Screen Layout */}
            <div class="playlists-container">
                {/* LEFT PANE: Quick Connect Card */}
                <div class="playlists-library">
                    <div class="pane-header">
                        <div>
                            <h2>{tr("Playlists")}</h2>
                            <p class="muted">
                                Active IPTV and Xtream playlists configured on this TV.
                            </p>
                        </div>
                        <button
                            class="add-playlist-btn primary"
                            onClick={openAddModal}
                        >{tr("+ Add Playlist")}</button>
                    </div>

                    <div class="playlists-list">
                        {tv.data.sources.length === 0 ? (
                            <div class="empty-playlists-box">
                                <p>No playlists connected yet.</p>
                                <p class="muted">
                                    Add one manually with the button above or scan the
                                    QR code on the left to add from your phone.
                                </p>
                            </div>
                        ) : (
                            tv.data.sources.map((source) => {
                                const isActive = tv.data.activeId === source.id;
                                return (
                                    <div
                                        class={`playlist-card ${isActive ? 'active' : ''
                                            }`}
                                        key={source.id}
                                    >
                                        <div class="playlist-card-main">
                                            <div class="playlist-info">
                                                <div class="playlist-title-row">
                                                    {isActive ? (
                                                        <span class="active-indicator">
                                                            ● ACTIVE
                                                        </span>
                                                    ) : null}
                                                    <span class="playlist-name">
                                                        {source.name}
                                                    </span>
                                                    <span class="provider-pill">
                                                        {source.provider.toUpperCase()}
                                                    </span>
                                                </div>
                                                <span class="playlist-url">
                                                    {source.url}
                                                </span>
                                            </div>

                                            <div class="playlist-actions">
                                                {!isActive ? (
                                                    <button
                                                        class="action-btn select-btn"
                                                        onClick={() => {
                                                            void tv.switchSource(
                                                                source.id
                                                            );
                                                        }}
                                                    >{tr("Select")}</button>
                                                ) : null}
                                                <button
                                                    class="action-btn edit-btn"
                                                    disabled={!!source.m3uItems}
                                                    onClick={() => openEditModal(source)}
                                                >
                                                    {source.m3uItems
                                                        ? 'Stored'
                                                        : 'Edit'}
                                                </button>
                                                <button
                                                    class="action-btn remove-btn"
                                                    onClick={() => {
                                                        if (
                                                            confirm(
                                                                `Remove "${source.name}" and its channels from this TV?`
                                                            )
                                                        ) {
                                                            const currentReg = registration || loadStoredTvRegistration();
                                                            if (currentReg) {
                                                                void deleteTvCloudPlaylist(currentReg, source.id);
                                                            }
                                                            tv.update((d) =>
                                                                removeSourceData(
                                                                    d,
                                                                    source.id
                                                                )
                                                            ).catch(() =>
                                                                tv.setError(
                                                                    'Playlist was not removed.'
                                                                )
                                                            );
                                                        }
                                                    }}
                                                >{tr("Remove")}</button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>

                <div class="playlists-connect">
                    <div class="quick-connect-card">
                        <div class="quick-connect-header">
                            <span class="quick-connect-badge">{tr("QUICK CONNECT")}</span>
                            <span class={`status-pill ${status}`}>
                                ● {status.toUpperCase()} ({plan})
                            </span>
                        </div>

                        <div class="qr-wrapper">
                            {qrDataUrl ? (
                                <img
                                    src={qrDataUrl}
                                    alt="Pairing QR Code"
                                    class="qr-image"
                                />
                            ) : (
                                <div class="qr-placeholder">Loading QR…</div>
                            )}
                        </div>

                        <p class="quick-connect-instructions">
                            Scan to manage your playlists from your smartphone or
                            computer without typing with your TV remote.
                        </p>

                        <div class="credentials-box">
                            <div class="credential-row">
                                <span class="cred-label">{tr("MAC ADDRESS")}</span>
                                <span class="cred-val highlight">{mac}</span>
                            </div>
                            <div class="credential-row">
                                <span class="cred-label">{tr("DEVICE KEY")}</span>
                                <span class="cred-val highlight key-badge">
                                    {key}
                                </span>
                            </div>
                            <div class="credential-row">
                                <span class="cred-label">{tr("WEB PORTAL")}</span>
                                <span class="cred-val muted-val">
                                    /customer/login
                                </span>
                            </div>
                        </div>

                        <button
                            class="sync-btn"
                            onClick={handleSyncCloud}
                            disabled={syncing}
                        >
                            {syncing ? 'Syncing Cloud…' : '↻ Sync Cloud Playlists'}
                        </button>
                        {syncMsg ? <p class="sync-status">{syncMsg}</p> : null}
                    </div>
                </div>

            </div>

            {/* ADD / EDIT PLAYLIST MODAL WITH PREMIUM GLASSMORPHIC DESIGN */}
            {showDialog ? (
                <div class="modal-backdrop">
                    <div class="playlist-modal">
                        <div class="modal-header">
                            <div class="modal-title-box">
                                <span class="modal-supertitle">PLAYLIST CONFIGURATION</span>
                                <h3>
                                    {editing ? 'Edit Playlist Settings' : 'Add New Streaming Source'}
                                </h3>
                            </div>
                            <button
                                class="close-btn"
                                onClick={() => setShowDialog(false)}
                                title={tr("Close dialog")}
                            >
                                ✕
                            </button>
                        </div>

                        {/* Interactive Mode Cards: Xtream vs M3U */}
                        <div class="provider-type-selector">
                            <div
                                class={`provider-card-btn ${type === 'xtream' ? 'selected' : ''}`}
                                onClick={() => setType('xtream')}
                                tabIndex={0}
                                onKeyDown={(e: any) => { if (e.key === 'Enter') setType('xtream'); }}
                            >
                                <div class="provider-card-icon">⚡</div>
                                <div class="provider-card-content">
                                    <div class="provider-card-title">Xtream Codes API</div>
                                    <div class="provider-card-desc">Server URL + Username + Password (Fast & EPG ready)</div>
                                </div>
                                <div class="provider-card-radio">{type === 'xtream' ? '●' : '○'}</div>
                            </div>

                            <div
                                class={`provider-card-btn ${type === 'm3u' ? 'selected' : ''}`}
                                onClick={() => setType('m3u')}
                                tabIndex={0}
                                onKeyDown={(e: any) => { if (e.key === 'Enter') setType('m3u'); }}
                            >
                                <div class="provider-card-icon">📁</div>
                                <div class="provider-card-content">
                                    <div class="provider-card-title">M3U Playlist URL</div>
                                    <div class="provider-card-desc">Direct .m3u or .m3u8 link from any provider</div>
                                </div>
                                <div class="provider-card-radio">{type === 'm3u' ? '●' : '○'}</div>
                            </div>
                        </div>

                        <form class="modal-form" onSubmit={submit}>
                            <div class="form-field-group">
                                <label class="form-label">
                                    <span class="label-heading">PLAYLIST NICKNAME</span>
                                    <input
                                        name="name"
                                        class="tv-input"
                                        required
                                        placeholder="e.g. My Premium VIP"
                                        defaultValue={editing?.name}
                                    />
                                </label>
                            </div>

                            <div class="form-field-group">
                                <label class="form-label">
                                    <span class="label-heading">
                                        {type === 'm3u'
                                            ? 'M3U PLAYLIST WEB LINK'
                                            : 'XTREAM SERVER ADDRESS'}
                                    </span>
                                    <input
                                        name="url"
                                        class="tv-input"
                                        type="url"
                                        required
                                        defaultValue={editing?.url}
                                        placeholder={
                                            type === 'm3u'
                                                ? 'http://example.com/get.php?username=...&password=...'
                                                : 'http://example.com:8080'
                                        }
                                    />
                                </label>
                            </div>

                            {type === 'xtream' ? (
                                <div class="form-row-dual">
                                    <label class="form-label">
                                        <span class="label-heading">USERNAME</span>
                                        <input
                                            name="username"
                                            class="tv-input"
                                            required
                                            defaultValue={editing?.username}
                                            autoComplete="off"
                                            placeholder="Account username"
                                        />
                                    </label>
                                    <label class="form-label">
                                        <span class="label-heading">PASSWORD</span>
                                        <input
                                            name="password"
                                            class="tv-input"
                                            type="password"
                                            required
                                            defaultValue={editing?.password}
                                            autoComplete="off"
                                            placeholder="Account password"
                                        />
                                    </label>
                                </div>
                            ) : null}

                            {failure ? (
                                <div class="form-error-banner" role="alert">
                                    <span class="error-icon">⚠️</span>
                                    <span class="error-text">{failure}</span>
                                </div>
                            ) : null}

                            <div class="modal-actions">
                                <button
                                    type="button"
                                    class="cancel-btn"
                                    onClick={() => setShowDialog(false)}
                                >{tr("Cancel")}</button>
                                <button
                                    type="submit"
                                    class="save-btn primary"
                                    disabled={saving}
                                >
                                    {saving
                                        ? 'Testing & Saving…'
                                        : 'Connect & Save Playlist'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            ) : null}
        </div>
    );
}
