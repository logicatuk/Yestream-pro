import { useState, useEffect } from 'preact/hooks';
import QRCode from 'qrcode';
import {
    TvDeviceRegistration,
    syncTvDevice,
    YESTREAM_CLOUD_ORIGIN,
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

    const portalUrl =
        registration.portalLoginUrl ||
        buildCustomerLoginUrl(registration.mac, registration.key6 || registration.deviceKey);

    useEffect(() => {
        let mounted = true;
        void QRCode.toDataURL(portalUrl, {
            width: 260,
            margin: 2,
            errorCorrectionLevel: 'M',
            color: { dark: '#0b1329', light: '#ffffff' },
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
        setMsg('Checking renewal status with server…');
        try {
            const { registration: updated } = await syncTvDevice(registration);
            onStatusRefreshed(updated);
            if (updated.status === 'active' || updated.status === 'trial') {
                setMsg('Subscription active! Unlocking TV…');
            } else {
                setMsg('Subscription is still marked as expired. Please renew online.');
            }
        } catch {
            setMsg('Unable to reach server. Please check internet connection.');
        } finally {
            setChecking(false);
        }
    }

    return (
        <div class="tv-expiry-lockscreen">
            <div class="expiry-modal-card">
                <div class="lock-icon-circle">
                    <svg
                        width="48"
                        height="48"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="#f87171"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                </div>

                <h1>Subscription Expired</h1>
                <p class="expiry-subtitle">
                    Your access period has expired. Scan the QR code or visit the portal to renew your device access.
                </p>

                <div class="expiry-qr-container">
                    {qrUrl ? (
                        <img src={qrUrl} alt="Renewal QR Code" class="expiry-qr-img" />
                    ) : (
                        <div class="qr-placeholder">Loading QR…</div>
                    )}
                </div>

                <div class="expiry-creds-banner">
                    <div class="cred-chip">
                        <span>MAC:</span>
                        <strong>{registration.mac}</strong>
                    </div>
                    <div class="cred-chip">
                        <span>KEY:</span>
                        <strong>{registration.key6 || registration.deviceKey}</strong>
                    </div>
                    <div class="cred-chip">
                        <span>PORTAL:</span>
                        <strong>/customer/login</strong>
                    </div>
                </div>

                {msg ? <p class="expiry-feedback-msg">{msg}</p> : null}

                <div class="expiry-btn-group">
                    <button
                        class="refresh-btn primary"
                        onClick={handleCheckStatus}
                        disabled={checking}
                    >
                        {checking ? 'Checking Status…' : '↻ Check Status & Unlock'}
                    </button>
                    <button class="settings-fallback-btn" onClick={onOpenSettings}>
                        Manage Playlists & Settings
                    </button>
                </div>
            </div>
        </div>
    );
}
