import { useState, useEffect, useLayoutEffect, useRef } from 'preact/hooks';
import QRCode from 'qrcode';
import {
    TvDeviceRegistration,
    syncTvDevice,
    buildCustomerLoginUrl,
} from '@iptvnator/tv/data-access';

export function TvExpiryGuard({
    registration,
    onStatusRefreshed,
    onOpenSettings,
}: {
    registration: TvDeviceRegistration;
    onStatusRefreshed: (updated: TvDeviceRegistration) => void;
    onOpenSettings: () => void;
}) {
    const [qrUrl, setQrUrl] = useState<string>('');
    const [checking, setChecking] = useState<boolean>(false);
    const [msg, setMsg] = useState<string>('');
    const refreshBtnRef = useRef<HTMLButtonElement>(null);

    const portalUrl =
        registration.portalLoginUrl ||
        buildCustomerLoginUrl(registration.mac, registration.key6 || registration.deviceKey);

    useLayoutEffect(() => {
        refreshBtnRef.current?.focus();
    }, []);

    useEffect(() => {
        let mounted = true;
        void QRCode.toDataURL(portalUrl, {
            width: 260,
            margin: 2,
            errorCorrectionLevel: 'M',
            color: { dark: '#04060b', light: '#ffffff' },
        }).then((qr) => {
            if (mounted) setQrUrl(qr);
        });
        return () => {
            mounted = false;
        };
    }, [portalUrl]);

    async function handleCheckStatus() {
        if (checking) return;
        setChecking(true);
        setMsg('Checking activation with Yestream Cloud…');
        try {
            const { registration: updated } = await syncTvDevice(registration);
            onStatusRefreshed(updated);
            if (updated.status === 'active' || updated.status === 'trial') {
                setMsg('Device active! Unlocking TV…');
            } else {
                setMsg('Subscription is still expired. Please complete renewal above.');
            }
        } catch {
            setMsg('Unable to reach server. Please check internet connection.');
        } finally {
            setChecking(false);
        }
    }

    return (
        <div class="tv-expiry-lockscreen" role="alertdialog" aria-modal aria-label="Subscription Expired">
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
                        <h2>Your trial period has expired.</h2>
                    </div>
                    <p class="expiry-alert-subtitle">
                        To continue enjoying Live TV, Movies, Series, and the EPG Timeline, please renew or activate your device.
                    </p>
                </div>

                {/* 3. ACTIVATION HERO CARD (Split Screen: QR Code + Credentials) */}
                <div class="expiry-card-split">
                    {/* Left: QR Code */}
                    <div class="expiry-qr-col">
                        <div class="qr-white-card">
                            {qrUrl ? (
                                <img src={qrUrl} alt="Renewal QR Code" class="expiry-qr-image" />
                            ) : (
                                <div class="qr-loading-box">Loading QR…</div>
                            )}
                        </div>
                        <span class="qr-scan-hint">Scan with phone to activate</span>
                    </div>

                    <div class="expiry-divider" />

                    {/* Right: Hardware MAC + Activation Key */}
                    <div class="expiry-details-col">
                        <div class="cred-field-group">
                            <span class="field-label">DEVICE MAC ADDRESS</span>
                            <div class="field-value-pill mac-pill">
                                {registration.mac || 'DA:E5:4A:7C:18:3F'}
                            </div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">DEVICE ACTIVATION KEY</span>
                            <div class="field-value-pill key-pill">
                                {registration.key6 || registration.deviceKey || '••••••'}
                            </div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">PORTAL URL</span>
                            <span class="portal-url-text">https://yestream.app/activate</span>
                        </div>
                    </div>
                </div>

                {/* 4. ACTION BUTTONS: Refresh Status & Manage Playlists */}
                <div class="expiry-action-row">
                    <button
                        ref={refreshBtnRef}
                        class="expiry-btn primary-refresh"
                        data-focus="expiry-refresh"
                        onClick={handleCheckStatus}
                        disabled={checking}
                    >
                        {checking ? 'Checking…' : '↻ Refresh Status'}
                    </button>

                    <button
                        class="expiry-btn secondary-playlists"
                        data-focus="expiry-playlists"
                        onClick={onOpenSettings}
                    >
                        ☰ Manage Playlists
                    </button>
                </div>

                {msg ? <p class="expiry-result-msg" role="status">{msg}</p> : null}
            </div>
        </div>
    );
}
