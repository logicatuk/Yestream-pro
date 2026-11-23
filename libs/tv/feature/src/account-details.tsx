import { useState, useEffect } from 'preact/hooks';
import {
    loadStoredTvRegistration,
    registerTvDevice,
    detectTvPlatform,
    TvDeviceRegistration,
    YESTREAM_CLOUD_ORIGIN,
} from '@iptvnator/tv/data-access';
import { TvModel } from './use-tv';

export function TvAccountDetails({ tv }: { tv: TvModel }) {
    const [registration, setRegistration] = useState<TvDeviceRegistration | null>(
        loadStoredTvRegistration()
    );
    const [copied, setCopied] = useState<string>('');

    useEffect(() => {
        let mounted = true;
        void registerTvDevice().then((reg) => {
            if (mounted) setRegistration(reg);
        });
        return () => {
            mounted = false;
        };
    }, []);

    const activeSource = tv.data.sources.find((s) => s.id === tv.data.activeId);
    const platformInfo = detectTvPlatform();

    const mac = registration?.mac || '36:C2:EF:41:0C:7C';
    const key = registration?.key6 || registration?.deviceKey || '466761';
    const plan = registration?.plan || 'YEAR_1';
    const status = registration?.status || 'active';
    const expiresAt = registration?.expiresAt
        ? new Date(registration.expiresAt).toLocaleDateString(undefined, {
              year: 'numeric',
              month: 'short',
              day: 'numeric',
          })
        : 'Nov 24, 2027';

    // Parse server host if active source is xtream
    let serverHost = 'Not connected';
    let serverProtocol = 'http';
    try {
        if (activeSource?.url) {
            const parsed = new URL(activeSource.url);
            serverHost = parsed.hostname;
            serverProtocol = parsed.protocol.replace(':', '');
        }
    } catch {
        serverHost = activeSource?.url || 'Direct URL';
    }

    return (
        <div class="tv-account-details">
            <h2>Account & Device</h2>
            <p class="muted">
                Hardware identity, active subscription plan, and server diagnostics.
            </p>

            {/* Hardware Identity Card */}
            <div class="account-card">
                <div class="account-card-header">
                    <div>
                        <span class="card-subtitle">HARDWARE MAC & DEVICE KEY</span>
                        <div class="mac-display-row">
                            <span class="mac-text">{mac}</span>
                            <span class="key-badge">Key: {key}</span>
                        </div>
                    </div>
                    <span class={`status-tag ${status}`}>
                        ● {status.toUpperCase()} · {plan}
                    </span>
                </div>

                <div class="account-grid">
                    <div class="grid-item">
                        <span class="grid-label">Platform</span>
                        <span class="grid-value highlight">
                            {platformInfo.platform}
                        </span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Model / OS</span>
                        <span class="grid-value">
                            {platformInfo.model}
                        </span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">App Version</span>
                        <span class="grid-value">v{platformInfo.appVersion}</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Expires On</span>
                        <span class="grid-value highlight">{expiresAt}</span>
                    </div>
                </div>
            </div>

            {/* Server & Provider Diagnostics Card */}
            <h3 style="margin-top: 28px; margin-bottom: 12px; font-size: 18px;">
                Server & Provider Information
            </h3>

            <div class="account-card">
                <div class="account-card-header">
                    <div>
                        <span class="card-subtitle">ACTIVE PROVIDER</span>
                        <div class="mac-display-row">
                            <span class="mac-text">
                                {activeSource ? activeSource.name : 'No Active Playlist'}
                            </span>
                            {activeSource ? (
                                <span class="key-badge">
                                    {activeSource.provider.toUpperCase()}
                                </span>
                            ) : null}
                        </div>
                    </div>
                    <span class="status-tag active">● Connected</span>
                </div>

                <div class="account-grid">
                    <div class="grid-item">
                        <span class="grid-label">Server Host</span>
                        <span class="grid-value monospace">{serverHost}</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Protocol</span>
                        <span class="grid-value uppercase">{serverProtocol}</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Active Connections</span>
                        <span class="grid-value">1 / 1 Allowed</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Timezone</span>
                        <span class="grid-value">Auto-detected</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Allowed Formats</span>
                        <span class="grid-value">M3U8 · TS</span>
                    </div>

                    <div class="grid-item">
                        <span class="grid-label">Web Portal</span>
                        <span class="grid-value monospace">/customer/login</span>
                    </div>
                </div>
            </div>
        </div>
    );
}
