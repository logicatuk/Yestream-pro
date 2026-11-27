import { tr } from '@iptvnator/tv/ui';
import { useEffect, useState } from 'preact/hooks';
import { TvModel } from './use-tv';

export interface XtreamUserInfo {
    username?: string;
    activeConnections?: string | number;
    maxConnections?: string | number;
    expDate?: string;
    isTrial?: string | number | boolean;
    allowedOutputFormats?: string[];
    createdAt?: string;
    serverUrl?: string;
    serverProtocol?: string;
    serverTimezone?: string;
    serverTime?: string;
    rtmpPort?: string;
    port?: string;
    httpsPort?: string;
}

/** Derives a stable MAC-like display string from the backend URL. */
function deriveMac(seed: string): string {
    let h = 0x811c9dc5;
    for (let i = 0; i < seed.length; i++) {
        h ^= seed.charCodeAt(i);
        h = (h * 0x01000193) >>> 0;
    }
    const hex = (h >>> 0).toString(16).padStart(8, '0').toUpperCase();
    return `YE:ST:${hex.slice(0, 2)}:${hex.slice(2, 4)}:${hex.slice(4, 6)}:${hex.slice(6, 8)}`;
}

function deriveKey(seed: string): string {
    let h = 0x9e3779b9;
    for (let i = 0; i < seed.length; i++) {
        h ^= seed.charCodeAt(i);
        h = (h * 0x01000193) >>> 0;
    }
    return String((h >>> 0) % 900000 + 100000);
}

function formatDate(ts: string | number | undefined): string {
    if (!ts) return 'N/A';
    const n = Number(ts);
    const d = isNaN(n) ? new Date(ts as string) : new Date(n * 1000);
    if (isNaN(d.getTime())) return String(ts);
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

function InfoRow({ label, value }: { label: string; value: string }) {
    return (
        <div class="account-row">
            <dt class="account-row-label">{label}</dt>
            <dd class="account-row-value">{value}</dd>
        </div>
    );
}

/** Account & Device panel rendered inside Settings → Account tab. */
export function AccountPanel({ tv }: { tv: TvModel }) {
    const mac = deriveMac(tv.data.backend || window.location.hostname);
    const deviceKey = deriveKey(tv.data.backend || window.location.hostname);
    const portalUrl = 'yestream.tv/connect';

    const [xtream, setXtream] = useState<XtreamUserInfo | null>(null);
    const [loadingXtream, setLoadingXtream] = useState(false);
    const [xtreamError, setXtreamError] = useState('');

    const activeSource = tv.data.sources.find(
        (s) => s.id === tv.data.activeId
    );

    // Load Xtream user info when active source is Xtream
    useEffect(() => {
        if (!activeSource || activeSource.provider !== 'xtream') {
            setXtream(null);
            return;
        }
        if (!tv.data.backend) return;

        const abort = new AbortController();
        setLoadingXtream(true);
        setXtreamError('');

        // Proxy through backend transport for Xtream user info
        fetch(
            `${tv.data.backend}/api/xtream/user-info?` +
                new URLSearchParams({
                    url: activeSource.url,
                    username: activeSource.username ?? '',
                    password: activeSource.password ?? '',
                }),
            {
                signal: abort.signal,
                headers: tv.data.backendToken
                    ? { Authorization: `Bearer ${tv.data.backendToken}` }
                    : {},
            }
        )
            .then((r) => r.json())
            .then((data: XtreamUserInfo) => {
                if (!abort.signal.aborted) setXtream(data);
            })
            .catch(() => {
                if (!abort.signal.aborted)
                    setXtreamError('Could not load Xtream account info.');
            })
            .finally(() => {
                if (!abort.signal.aborted) setLoadingXtream(false);
            });

        return () => abort.abort();
    }, [activeSource?.id, tv.data.backend]);

    return (
        <section class="account-panel" aria-label={tr("Account & Device")}>
            <h2>Account &amp; Device</h2>

            {/* Device Identity */}
            <section class="account-section">
                <h3>Device Identity</h3>
                <dl>
                    <InfoRow label={tr("MAC Address")} value={mac} />
                    <InfoRow label={tr("Device Key")} value={deviceKey} />
                    <InfoRow label={tr("Portal")} value={portalUrl} />
                    {tv.data.backend ? (
                        <InfoRow label="Backend" value={tv.data.backend} />
                    ) : null}
                </dl>
            </section>

            {/* Active Playlist */}
            {activeSource ? (
                <section class="account-section">
                    <h3>Active Playlist</h3>
                    <dl>
                        <InfoRow label={tr("Name")} value={activeSource.name} />
                        <InfoRow label={tr("Type")} value={activeSource.provider.toUpperCase()} />
                        <InfoRow label={tr("URL")} value={activeSource.url} />
                    </dl>
                </section>
            ) : (
                <section class="account-section">
                    <h3>Active Playlist</h3>
                    <p class="muted">No active playlist selected.</p>
                </section>
            )}

            {/* Xtream Provider Info */}
            {activeSource?.provider === 'xtream' ? (
                <section class="account-section">
                    <h3>Xtream Provider</h3>
                    {loadingXtream ? (
                        <p class="muted">Loading provider info…</p>
                    ) : xtreamError ? (
                        <p class="muted">{xtreamError}</p>
                    ) : xtream ? (
                        <>
                            <dl>
                                <InfoRow
                                    label={tr("Username")}
                                    value={xtream.username ?? activeSource.username ?? '—'}
                                />
                                <InfoRow
                                    label="Active Streams"
                                    value={`${xtream.activeConnections ?? '—'} / ${xtream.maxConnections ?? '—'}`}
                                />
                                <InfoRow
                                    label={tr("Expires")}
                                    value={formatDate(xtream.expDate)}
                                />
                                <InfoRow
                                    label="Trial"
                                    value={
                                        xtream.isTrial === '1' ||
                                        xtream.isTrial === 1 ||
                                        xtream.isTrial === true
                                            ? 'Yes'
                                            : 'No'
                                    }
                                />
                                {xtream.allowedOutputFormats?.length ? (
                                    <InfoRow
                                        label="Formats"
                                        value={xtream.allowedOutputFormats.join('  ')}
                                    />
                                ) : null}
                            </dl>
                            {xtream.serverUrl ? (
                                <>
                                    <h3 class="account-subheading">{tr("Server")}</h3>
                                    <dl>
                                        <InfoRow label={tr("URL")} value={xtream.serverUrl} />
                                        {xtream.serverProtocol ? (
                                            <InfoRow label={tr("Protocol")} value={xtream.serverProtocol} />
                                        ) : null}
                                        {xtream.serverTimezone ? (
                                            <InfoRow label={tr("Timezone")} value={xtream.serverTimezone} />
                                        ) : null}
                                        {xtream.serverTime ? (
                                            <InfoRow label="Server time" value={xtream.serverTime} />
                                        ) : null}
                                        {xtream.port || xtream.httpsPort || xtream.rtmpPort ? (
                                            <InfoRow
                                                label={tr("Ports")}
                                                value={[
                                                    xtream.port && `HTTP ${xtream.port}`,
                                                    xtream.httpsPort && `HTTPS ${xtream.httpsPort}`,
                                                    xtream.rtmpPort && `RTMP ${xtream.rtmpPort}`,
                                                ]
                                                    .filter(Boolean)
                                                    .join('  ')}
                                            />
                                        ) : null}
                                    </dl>
                                </>
                            ) : null}
                        </>
                    ) : null}
                </section>
            ) : null}
        </section>
    );
}
