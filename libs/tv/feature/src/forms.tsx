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
                // Add any newly synced cloud playlists to local tv data
                for (const cp of playlists) {
                    const existing = tv.data.sources.find((s) => s.id === cp.id || s.name === cp.name);
                    if (!existing && (cp.type === 'xtream' || cp.type === 'm3u')) {
                        const newSource: Source = {
                            id: cp.id || `cloud-${Date.now()}`,
                            name: cp.name,
                            provider: cp.type as Provider,
                            url: httpUrl(cp.type === 'xtream' ? cp.host || cp.url || '' : cp.url || ''),
                            ...(cp.type === 'xtream'
                                ? { username: cp.username, password: cp.password }
                                : {}),
                        };
                        await tv.saveSource(newSource);
                    }
                }
                setSyncMsg(`Synced! ${playlists.length} cloud playlist(s) updated.`);
            } else {
                setSyncMsg('Device synced. No new cloud playlists.');
            }
        } catch {
            setSyncMsg('Sync failed. Please check internet connection.');
        } finally {
            setSyncing(false);
            setTimeout(() => setSyncMsg(''), 4000);
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
            setShowDialog(false);
        } catch {
            setFailure(
                'Invalid URL. Please use a valid HTTP or HTTPS address without inline credentials.'
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
                <div class="playlists-left-pane">
                    <div class="quick-connect-card">
                        <div class="quick-connect-header">
                            <span class="quick-connect-badge">
                                QUICK CONNECT
                            </span>
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
                                <span class="cred-label">MAC ADDRESS</span>
                                <span class="cred-val highlight">{mac}</span>
                            </div>
                            <div class="credential-row">
                                <span class="cred-label">DEVICE KEY</span>
                                <span class="cred-val highlight key-badge">
                                    {key}
                                </span>
                            </div>
                            <div class="credential-row">
                                <span class="cred-label">WEB PORTAL</span>
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

                {/* RIGHT PANE: Playlists List */}
                <div class="playlists-right-pane">
                    <div class="pane-header">
                        <div>
                            <h2>Playlists</h2>
                            <p class="muted">
                                Active IPTV and Xtream playlists configured on this TV.
                            </p>
                        </div>
                        <button
                            class="add-playlist-btn primary"
                            onClick={openAddModal}
                        >
                            + Add Playlist
                        </button>
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
                                        class={`playlist-card ${
                                            isActive ? 'active' : ''
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
                                                    >
                                                        Select
                                                    </button>
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
                                                >
                                                    Remove
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>
            </div>

            {/* ADD / EDIT PLAYLIST MODAL WITH 2 TABS */}
            {showDialog ? (
                <div class="modal-backdrop">
                    <div class="playlist-modal">
                        <div class="modal-header">
                            <h3>
                                {editing ? 'Edit Playlist' : 'Add New Playlist'}
                            </h3>
                            <button
                                class="close-btn"
                                onClick={() => setShowDialog(false)}
                            >
                                ✕
                            </button>
                        </div>

                        {/* 2 Tabs: Xtream vs M3U */}
                        <div class="modal-tabs">
                            <button
                                type="button"
                                class={`tab-btn ${
                                    type === 'xtream' ? 'active' : ''
                                }`}
                                onClick={() => setType('xtream')}
                            >
                                Xtream Codes API
                            </button>
                            <button
                                type="button"
                                class={`tab-btn ${
                                    type === 'm3u' ? 'active' : ''
                                }`}
                                onClick={() => setType('m3u')}
                            >
                                M3U Playlist
                            </button>
                        </div>

                        <form class="modal-form" onSubmit={submit}>
                            <label class="form-label">
                                Playlist Name
                                <input
                                    name="name"
                                    class="tv-input"
                                    required
                                    placeholder="e.g. My Premium IPTV"
                                    defaultValue={editing?.name}
                                />
                            </label>

                            <label class="form-label">
                                {type === 'm3u'
                                    ? 'M3U Playlist URL'
                                    : 'Server URL'}
                                <input
                                    name="url"
                                    class="tv-input"
                                    type="url"
                                    required
                                    defaultValue={editing?.url}
                                    placeholder={
                                        type === 'm3u'
                                            ? 'http://provider.link:8080/get.php?…'
                                            : 'http://provider.link:8080'
                                    }
                                />
                            </label>

                            {type === 'xtream' ? (
                                <div class="form-row-dual">
                                    <label class="form-label">
                                        Username
                                        <input
                                            name="username"
                                            class="tv-input"
                                            required
                                            defaultValue={editing?.username}
                                            autoComplete="off"
                                            placeholder="Username"
                                        />
                                    </label>
                                    <label class="form-label">
                                        Password
                                        <input
                                            name="password"
                                            class="tv-input"
                                            type="password"
                                            required
                                            defaultValue={editing?.password}
                                            autoComplete="off"
                                            placeholder="Password"
                                        />
                                    </label>
                                </div>
                            ) : null}

                            {failure ? (
                                <p class="form-error" role="alert">
                                    {failure}
                                </p>
                            ) : null}

                            <div class="modal-actions">
                                <button
                                    type="button"
                                    class="cancel-btn"
                                    onClick={() => setShowDialog(false)}
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    class="save-btn primary"
                                    disabled={saving}
                                >
                                    {saving
                                        ? 'Saving…'
                                        : 'Save & Connect'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            ) : null}
        </div>
    );
}
