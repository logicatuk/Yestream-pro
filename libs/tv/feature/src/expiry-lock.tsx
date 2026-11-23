import { useState, useRef, useEffect, useLayoutEffect } from 'preact/hooks';
import QRCode from 'qrcode';
import { TvModel } from './use-tv';

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

/** Full-screen expiry lock shown when the Yestream subscription has expired.
 *  Displays QR, MAC, Key, and a "Check Status" button that re-verifies. */
export function ExpiryLock({ tv }: { tv: TvModel }) {
    const [qr, setQr] = useState('');
    const [checking, setChecking] = useState(false);
    const [checkResult, setCheckResult] = useState('');
    const btnRef = useRef<HTMLButtonElement>(null);

    const mac = deriveMac(tv.data.backend || window.location.hostname);
    const deviceKey = deriveKey(tv.data.backend || window.location.hostname);
    const renewUrl = 'yestream.tv/renew';

    // Auto-focus the check button on mount
    useLayoutEffect(() => {
        btnRef.current?.focus();
    }, []);

    // Generate QR for the renewal/portal URL
    useEffect(() => {
        const url = tv.data.backend
            ? `${tv.data.backend}/renew?mac=${encodeURIComponent(mac)}&key=${deviceKey}`
            : `https://${renewUrl}`;
        QRCode.toDataURL(url, {
            width: 240,
            margin: 3,
            errorCorrectionLevel: 'M',
            color: { dark: '#ffffff', light: '#0d1a14' },
        })
            .then(setQr)
            .catch(() => undefined);
    }, [tv.data.backend]);

    async function checkStatus() {
        setChecking(true);
        setCheckResult('');
        try {
            if (tv.data.backend) {
                const res = await fetch(`${tv.data.backend}/api/status`, {
                    headers: tv.data.backendToken
                        ? { Authorization: `Bearer ${tv.data.backendToken}` }
                        : {},
                });
                if (res.ok) {
                    setCheckResult('✓ Access restored! Reloading…');
                    setTimeout(() => window.location.reload(), 1200);
                } else {
                    setCheckResult('Still expired. Contact your provider or scan the QR code.');
                }
            } else {
                setCheckResult('No backend configured. Connect to a backend first.');
            }
        } catch {
            setCheckResult('Could not reach backend. Check your network connection.');
        } finally {
            setChecking(false);
        }
    }

    return (
        <div class="expiry-lock" role="alertdialog" aria-label="Access Expired" aria-modal>
            <div class="expiry-lock-inner">
                <div class="expiry-lock-icon" aria-hidden="true">🔒</div>
                <h1 class="expiry-lock-title">Access Period Ended</h1>
                <p class="expiry-lock-subtitle muted">
                    Your Yestream subscription has expired.<br />
                    Scan the code below or contact your provider to renew.
                </p>

                <div class="expiry-lock-content">
                    {qr ? (
                        <div class="expiry-lock-qr">
                            <img src={qr} alt="Renewal QR code" width={200} height={200} />
                        </div>
                    ) : null}

                    <div class="expiry-lock-credentials">
                        <div class="expiry-cred-row">
                            <span class="expiry-cred-label">MAC</span>
                            <code class="expiry-cred-value">{mac}</code>
                        </div>
                        <div class="expiry-cred-row">
                            <span class="expiry-cred-label">Key</span>
                            <code class="expiry-cred-value expiry-cred-key">{deviceKey}</code>
                        </div>
                        <div class="expiry-cred-row">
                            <span class="expiry-cred-label">Web</span>
                            <span class="expiry-cred-value muted">{renewUrl}</span>
                        </div>
                    </div>
                </div>

                {checkResult ? (
                    <p
                        role="status"
                        class={`expiry-lock-result${checkResult.startsWith('✓') ? ' expiry-lock-result--ok' : ''}`}
                    >
                        {checkResult}
                    </p>
                ) : null}

                <button
                    ref={btnRef}
                    class="primary expiry-lock-btn"
                    disabled={checking}
                    onClick={() => void checkStatus()}
                    data-focus="expiry-check"
                >
                    {checking ? 'Checking…' : '↺ Check Status & Unlock'}
                </button>
            </div>
        </div>
    );
}
