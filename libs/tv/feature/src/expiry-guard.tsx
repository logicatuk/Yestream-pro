import { tr } from '@iptvnator/tv/ui';
import { useState, useEffect, useLayoutEffect, useRef } from 'preact/hooks';
import { installRemote } from '@iptvnator/tv/ui';
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
    onOpenSettings?: () => void;
}) {
    const [qrUrl, setQrUrl] = useState<string>('');
    const [checking, setChecking] = useState<boolean>(false);
    const [msg, setMsg] = useState<string>('');
    const refreshBtnRef = useRef<HTMLButtonElement>(null);

    const portalUrl =
        registration.portalLoginUrl ||
        buildCustomerLoginUrl(registration.mac, registration.key6 || registration.deviceKey);

    useLayoutEffect(() => {
        const focusRefresh = () => refreshBtnRef.current?.focus();
        focusRefresh();
        return installRemote(focusRefresh, () => false, () => undefined);
    }, []);

    useEffect(() => {
        let mounted = true;
        void QRCode.toDataURL(portalUrl, {
            width: 320,
            margin: 4,
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
        <div class="tv-expiry-lockscreen" data-tv-modal role="alertdialog" aria-modal aria-label={tr("Subscription Expired")}>
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
                        <span class="qr-scan-hint">{tr("Scan with phone to activate")}</span>
                    </div>

                    <div class="expiry-divider" />

                    {/* Right: Hardware MAC + Activation Key */}
                    <div class="expiry-details-col">
                        <div class="cred-field-group">
                            <span class="field-label">{tr("DEVICE MAC ADDRESS")}</span>
                            <div class="field-value-pill mac-pill">
                                {registration.mac || '—'}
                            </div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">{tr("DEVICE ACTIVATION KEY")}</span>
                            <div class="field-value-pill key-pill">
                                {registration.key6 || registration.deviceKey || '••••••'}
                            </div>
                        </div>

                        <div class="cred-field-group">
                            <span class="field-label">{tr("PORTAL URL")}</span>
                            <a href="https://yestream.ai.studio/" target="_blank" rel="noopener noreferrer" class="portal-url-text">https://yestream.ai.studio/</a>
                        </div>
                    </div>
                </div>

                {/* 4. ACTION BUTTON: Refresh Status */}
                <div class="expiry-action-row">
                    <button
                        ref={refreshBtnRef}
                        class="expiry-btn primary-refresh"
                        data-focus="expiry-refresh"
                        onClick={handleCheckStatus}
                        disabled={checking}
                    >
                        {tr(checking ? 'Checking…' : '↻ Refresh Status')}
                    </button>
                </div>

                {msg ? <p class="expiry-result-msg" role="status">{msg}</p> : null}
            </div>
        </div>
    );
}
