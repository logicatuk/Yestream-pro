import { useEffect, useRef, useState } from 'preact/hooks';
import QRCode from 'qrcode';
import {
    createPairing,
    finishPairing,
    pairingState,
    PairingSession,
    PairingState,
} from '@iptvnator/tv/data-access';
import { TvModel } from './use-tv';

/** Left-pane Quick Connect card for the Playlists screen.
 *  Shows QR code, MAC, 6-digit Device Key, and portal URL.
 *  Auto-renews the pairing session when it expires. */
export function PlaylistsQuickConnect({ tv }: { tv: TvModel }) {
    const [session, setSession] = useState<PairingSession>();
    const [_state, setState] = useState<PairingState>();
    const [qr, setQr] = useState('');
    const [remaining, setRemaining] = useState(0);
    const [error, setError] = useState('');
    const owner = useRef<{ session: PairingSession; backend: string }>();
    const operation = useRef<AbortController>();
    const saved = useRef(false);

    // Derive a stable device MAC from the backend URL (consistent fingerprint)
    const mac = deriveMac(tv.data.backend);
    const deviceKey = deriveKey(tv.data.backend);
    const portalUrl = 'yestream.tv/connect';

    async function start() {
        operation.current?.abort();
        const abort = new AbortController();
        operation.current = abort;
        setError('');
        try {
            if (!tv.data.backend) return;
            const next = await createPairing(
                tv.data.backend,
                tv.data.backendToken,
                abort.signal,
                'source'
            );
            if (abort.signal.aborted) return;
            owner.current = { session: next, backend: tv.data.backend };
            const url = `${tv.data.backend}/tv/setup#${next.id}.${next.phoneToken}`;
            setQr(
                await QRCode.toDataURL(url, {
                    width: 280,
                    margin: 3,
                    errorCorrectionLevel: 'M',
                    color: { dark: '#ffffff', light: '#1a2520' },
                })
            );
            if (abort.signal.aborted) return;
            setState(undefined);
            setSession(next);
            setRemaining(Math.ceil((next.expiresAt - Date.now()) / 1000));
        } catch {
            if (!abort.signal.aborted)
                setError('Could not load QR code. Check backend connection.');
        }
    }

    // Poll pairing state
    useEffect(() => {
        if (!session || !tv.data.backend) return;
        const abort = new AbortController();
        let timer: ReturnType<typeof setInterval>;
        const poll = () => {
            void pairingState(tv.data.backend, session, abort.signal)
                .then((s) => {
                    if (abort.signal.aborted) return;
                    setState(s);
                    setRemaining(Math.ceil((session.expiresAt - Date.now()) / 1000));
                    if (s.status === 'pending') {
                        // Source is coming from phone — handled by parent
                        saved.current = true;
                        clearInterval(timer);
                    }
                    if (s.status === 'saved') {
                        saved.current = true;
                        clearInterval(timer);
                        // Auto-refresh QR after short delay
                        setTimeout(() => void start(), 1500);
                    }
                })
                .catch(() => undefined);
        };
        timer = setInterval(poll, 3000);
        // Countdown display
        const countdown = setInterval(() => {
            const left = Math.ceil((session.expiresAt - Date.now()) / 1000);
            setRemaining(left);
            if (left <= 0) {
                clearInterval(countdown);
                void start(); // renew
            }
        }, 1000);
        return () => {
            clearInterval(timer);
            clearInterval(countdown);
            abort.abort();
        };
    }, [session?.id]);

    // Start on mount & when backend changes
    useEffect(() => {
        void start();
        return () => {
            operation.current?.abort();
            const current = owner.current;
            if (current && !saved.current)
                void finishPairing(
                    current.backend,
                    current.session,
                    'cancelled',
                    new AbortController().signal
                ).catch(() => undefined);
        };
    }, [tv.data.backend]);

    const mins = Math.floor(remaining / 60);
    const secs = String(remaining % 60).padStart(2, '0');
    const countdownLabel = remaining > 0 ? `${mins}:${secs}` : 'Refreshing…';

    return (
        <div class="playlists-qc">
            <div class="playlists-qc-heading">Scan to Add Playlist</div>
            <div class="playlists-qc-qr">
                {qr ? (
                    <img src={qr} alt="QR code — scan from your phone" width={200} height={200} />
                ) : error ? (
                    <div class="playlists-qc-error">{error}</div>
                ) : (
                    <div class="playlists-qc-loading">Loading QR…</div>
                )}
            </div>
            {qr && (
                <div class="playlists-qc-timer muted">
                    Expires in {countdownLabel}
                </div>
            )}
            <div class="playlists-qc-fields">
                <div class="playlists-qc-row">
                    <span class="playlists-qc-label">MAC</span>
                    <code class="playlists-qc-value">{mac}</code>
                </div>
                <div class="playlists-qc-row">
                    <span class="playlists-qc-label">Key</span>
                    <code class="playlists-qc-value playlists-qc-key">{deviceKey}</code>
                </div>
                <div class="playlists-qc-row">
                    <span class="playlists-qc-label">Web</span>
                    <span class="playlists-qc-value muted">{portalUrl}</span>
                </div>
            </div>
        </div>
    );
}

/** Deterministic 6-character MAC-like identifier from a backend URL seed. */
function deriveMac(seed: string): string {
    let h = 0x811c9dc5;
    for (let i = 0; i < seed.length; i++) {
        h ^= seed.charCodeAt(i);
        h = (h * 0x01000193) >>> 0;
    }
    const hex = (h >>> 0).toString(16).padStart(8, '0').toUpperCase();
    // Format as YE:ST:RE:AM:XX:XX
    return `YE:ST:${hex.slice(0, 2)}:${hex.slice(2, 4)}:${hex.slice(4, 6)}:${hex.slice(6, 8)}`;
}

/** Deterministic 6-digit key from backend URL. */
function deriveKey(seed: string): string {
    let h = 0x9e3779b9;
    for (let i = 0; i < seed.length; i++) {
        h ^= seed.charCodeAt(i);
        h = (h * 0x01000193) >>> 0;
    }
    return String((h >>> 0) % 900000 + 100000);
}
