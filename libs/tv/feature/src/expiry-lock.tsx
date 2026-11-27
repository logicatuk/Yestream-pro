import { tr } from '@iptvnator/tv/ui';
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
        <div class="expiry-lock" role="alertdialog" aria-label={tr("Subscription Expired")} aria-modal>
            <div class="expiry-luxury-container">
                {/* 1. BRAND HEADER (Authentic white origami bird logo) */}
                <div class="expiry-brand-header">
                    <img src="assets/logo.png" alt="Yestream" class="expiry-brand-logo" width="52" height="52" onError={(e) => {
                        const el = e.currentTarget as HTMLImageElement;
                        if (el.src.includes('assets/logo.png')) {
                            el.src = 'logo.png';
                        } else if (el.src.includes('logo.png')) {
                            el.src = '/logo.png';
                        }
                    }} />
                    <div class="expiry-brand-text">
                        <span class="brand-title">YESTREAM</span>
                        <span class="brand-subtitle">PRO IPTV PLAYER</span>
                    </div>
                </div>

                {/* 2. EXPIRED BANNER */}
                <div class="expiry-alert-header">
                    <div class="expiry-alert-title">
                        <span class="hourglass-icon">⏳</span>
                        <h2>{tr("Your trial period has expired.")}</h2>
                    </div>
                    <p class="expiry-alert-subtitle">{tr("To continue enjoying Live TV, Movies, Series, and the EPG Timeline, please renew or activate your device.")}</p>
                </div>

                {/* 3. HERO CARD */}
                <div class="expiry-card-split">
                    <div class="expiry-qr-col">
                        <div class="qr-white-card">
                            {qr ? (
                                <img src={qr} alt="Renewal QR code" class="expiry-qr-image" width={176} height={176} />
                            ) : (
                                <div class="qr-loading-box">Loading QR…</div>
                            )}
                        </div>
                        <span class="qr-scan-hint">{tr("Scan with phone to activate")}</span>
                    </div>

                    <div class="expiry-divider" />

                    <div class="expiry-details-col">
                        <div class="cred-field-group">
                            <span class="field-label">{tr("DEVICE MAC ADDRESS")}</span>
                            <div class="field-value-pill mac-pill">{mac}</div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">{tr("DEVICE ACTIVATION KEY")}</span>
                            <div class="field-value-pill key-pill">{deviceKey}</div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">{tr("PORTAL URL")}</span>
                            <a href="https://yestream.ai.studio/" target="_blank" rel="noopener noreferrer" class="portal-url-text">https://yestream.ai.studio/</a>
                        </div>
                    </div>
                </div>

                {checkResult ? (
                    <p
                        role="status"
                        class={`expiry-result-msg${checkResult.startsWith('✓') ? ' expiry-result-msg--ok' : ''}`}
                    >
                        {checkResult}
                    </p>
                ) : null}

                <div class="expiry-action-row">
                    <button
                        ref={btnRef}
                        class="expiry-btn primary-refresh"
                        disabled={checking}
                        onClick={() => void checkStatus()}
                        data-focus="expiry-check"
                    >
                        {checking ? 'Checking…' : '↻ Refresh Status'}
                    </button>
                </div>
            </div>
        </div>
    );
}
