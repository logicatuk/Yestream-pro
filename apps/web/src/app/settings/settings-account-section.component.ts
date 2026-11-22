import {
    ChangeDetectionStrategy,
    Component,
    computed,
    effect,
    inject,
    signal,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { Store } from '@ngrx/store';
import { selectActivePlaylist } from '@iptvnator/m3u-state';
import { YESTREAM_CLOUD_BRIDGE } from '@iptvnator/services';
import { XtreamApiService, XtreamStore, XtreamAccountInfo } from '@iptvnator/portal/xtream/data-access';

@Component({
    selector: 'app-settings-account-section',
    standalone: true,
    imports: [CommonModule, MatButtonModule, MatIconModule],
    template: `
        <section class="settings-group" id="account">
            <header class="settings-group__header">
                <h2>Account & Device</h2>
                <p>Your hardware device identity, Yestream Pro subscription, and active IPTV provider information.</p>
            </header>

            <!-- License & Device Card -->
            <section class="settings-section">
                <div class="settings-section__header">
                    <h3>Subscription & License</h3>
                </div>
                <div class="settings-card account-card">
                    <div class="account-card__top">
                        <div class="account-status-badge" [class.is-active]="isActive()" [class.is-expired]="isExpired()">
                            <mat-icon>{{ isActive() ? 'verified' : 'warning' }}</mat-icon>
                            <span>{{ statusLabel() }}</span>
                        </div>

                        <button
                            mat-stroked-button
                            type="button"
                            class="account-refresh-btn"
                            [disabled]="cloud?.syncLoading && cloud.syncLoading()"
                            (click)="checkStatus()"
                        >
                            <mat-icon [class.spinning]="cloud?.syncLoading && cloud.syncLoading()">sync</mat-icon>
                            <span>Check Status</span>
                        </button>
                    </div>

                    <div class="account-grid">
                        <div class="account-prop">
                            <span class="account-prop__label">MAC Address</span>
                            <div class="account-pill">
                                <code>{{ macAddress() }}</code>
                                <button
                                    type="button"
                                    class="account-copy-btn"
                                    (click)="copyText(macAddress(), 'mac')"
                                    title="Copy MAC"
                                >
                                    <mat-icon>{{ copiedField === 'mac' ? 'check' : 'content_copy' }}</mat-icon>
                                </button>
                            </div>
                        </div>

                        <div class="account-prop">
                            <span class="account-prop__label">Device Key</span>
                            <div class="account-pill">
                                <code class="key-highlight">{{ deviceKey() }}</code>
                                <button
                                    type="button"
                                    class="account-copy-btn"
                                    (click)="copyText(deviceKey(), 'key')"
                                    title="Copy Key"
                                >
                                    <mat-icon>{{ copiedField === 'key' ? 'check' : 'content_copy' }}</mat-icon>
                                </button>
                            </div>
                        </div>

                        <div class="account-prop">
                            <span class="account-prop__label">Subscription Plan</span>
                            <span class="account-prop__val plan-name">{{ planName() }}</span>
                        </div>

                        <div class="account-prop">
                            <span class="account-prop__label">Expiration Date</span>
                            <span class="account-prop__val">{{ expiresFormatted() }}</span>
                        </div>
                    </div>
                </div>
            </section>

            <!-- Active IPTV Provider Details -->
            <section class="settings-section">
                <div class="settings-section__header">
                    <h3>Active IPTV Provider</h3>
                    <p>Live stream statistics, user credentials, and server diagnostics from your current provider.</p>
                </div>

                @if (activePlaylist(); as p) {
                    @if (isXtream(p)) {
                        <!-- Xtream Codes Rich Account Info -->
                        <div class="settings-card provider-rich-card">
                            <!-- Eyebrow & Message Header -->
                            <div class="provider-hero">
                                <div class="provider-eyebrow">
                                    <span class="provider-eyebrow__dot"></span>
                                    <span>{{ serverProtocol() | uppercase }}</span>
                                    @if (serverTimezone()) {
                                        <span class="provider-eyebrow__sep">•</span>
                                        <span>{{ serverTimezone() | uppercase }}</span>
                                    }
                                </div>

                                @if (providerMessage()) {
                                    <div class="provider-message">
                                        <mat-icon>campaign</mat-icon>
                                        <span>{{ providerMessage() }}</span>
                                    </div>
                                }
                            </div>

                            <!-- 4 Hero Stats -->
                            <div class="hero-stats-grid">
                                <div class="hero-stat">
                                    <div class="hero-stat__icon"><mat-icon>bolt</mat-icon></div>
                                    <div class="hero-stat__body">
                                        <span class="hero-stat__label">Active Connections</span>
                                        <span class="hero-stat__value">{{ activeConnectionsLabel() }}</span>
                                        <div class="hero-stat__meter">
                                            <span [style.width.%]="connectionUsagePercent()"></span>
                                        </div>
                                    </div>
                                </div>

                                <div class="hero-stat">
                                    <div class="hero-stat__icon"><mat-icon>live_tv</mat-icon></div>
                                    <div class="hero-stat__body">
                                        <span class="hero-stat__label">Live TV</span>
                                        <span class="hero-stat__value">{{ liveCount() }}</span>
                                    </div>
                                </div>

                                <div class="hero-stat">
                                    <div class="hero-stat__icon"><mat-icon>movie</mat-icon></div>
                                    <div class="hero-stat__body">
                                        <span class="hero-stat__label">Movies</span>
                                        <span class="hero-stat__value">{{ vodCount() }}</span>
                                    </div>
                                </div>

                                <div class="hero-stat">
                                    <div class="hero-stat__icon"><mat-icon>tv</mat-icon></div>
                                    <div class="hero-stat__body">
                                        <span class="hero-stat__label">TV Series</span>
                                        <span class="hero-stat__value">{{ seriesCount() }}</span>
                                    </div>
                                </div>
                            </div>

                            <!-- Details Columns (User Info & Server Info) -->
                            <div class="provider-panels-grid">
                                <!-- User Information Panel -->
                                <div class="provider-panel">
                                    <h4 class="provider-panel__title">User Information</h4>
                                    <dl class="provider-dl">
                                        <div class="provider-row">
                                            <dt>Status</dt>
                                            <dd class="val-status" [class.is-active]="userStatus() === 'Active'">
                                                {{ userStatus() }}
                                            </dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Username</dt>
                                            <dd><code>{{ p.username || '—' }}</code></dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Active Connections</dt>
                                            <dd class="val-accent">{{ activeConnectionsLabel() }}</dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Created</dt>
                                            <dd>{{ userCreatedAt() }}</dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Expires</dt>
                                            <dd>{{ userExpDate() }}</dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Trial Account</dt>
                                            <dd [class.val-warning]="isTrialUser()">
                                                {{ isTrialUser() ? 'Yes' : 'No' }}
                                            </dd>
                                        </div>
                                    </dl>

                                    <!-- Allowed Formats Chips -->
                                    <div class="chips-section">
                                        <span class="chips-label">ALLOWED FORMATS</span>
                                        <div class="chips-wrap">
                                            @for (fmt of allowedFormats(); track fmt) {
                                                <span class="info-chip">{{ fmt }}</span>
                                            }
                                        </div>
                                    </div>
                                </div>

                                <!-- Server Information Panel -->
                                <div class="provider-panel">
                                    <h4 class="provider-panel__title">Server Information</h4>
                                    <dl class="provider-dl">
                                        <div class="provider-row">
                                            <dt>URL</dt>
                                            <dd><code>{{ serverHost() }}</code></dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Protocol</dt>
                                            <dd>{{ serverProtocol() }}</dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Timezone</dt>
                                            <dd>{{ serverTimezone() }}</dd>
                                        </div>
                                        <div class="provider-row">
                                            <dt>Server Time</dt>
                                            <dd><code>{{ serverTimeNow() }}</code></dd>
                                        </div>
                                    </dl>

                                    <!-- Ports Chips -->
                                    <div class="chips-section">
                                        <span class="chips-label">PORTS</span>
                                        <div class="chips-wrap">
                                            @for (port of serverPorts(); track port.name) {
                                                <span class="info-chip">{{ port.name }} {{ port.port }}</span>
                                            }
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    } @else {
                        <!-- Standard M3U Playlist Card -->
                        <div class="settings-card account-card">
                            <div class="provider-header">
                                <div class="provider-icon-wrap">
                                    <mat-icon>playlist_play</mat-icon>
                                </div>
                                <div class="provider-titles">
                                    <h4 class="provider-name">{{ p.title || p.filename || 'Untitled Playlist' }}</h4>
                                    <span class="provider-type-tag">M3U PLAYLIST</span>
                                </div>
                            </div>

                            <div class="account-grid">
                                <div class="account-prop full-width">
                                    <span class="account-prop__label">Playlist URL / File</span>
                                    <code class="endpoint-code">{{ p.url || p.filePath || 'Local Playlist' }}</code>
                                </div>

                                <div class="account-prop">
                                    <span class="account-prop__label">Channels / Streams</span>
                                    <span class="account-prop__val">{{ channelCount(p) }}</span>
                                </div>

                                <div class="account-prop">
                                    <span class="account-prop__label">Last Updated</span>
                                    <span class="account-prop__val">{{ lastUpdated(p) }}</span>
                                </div>
                            </div>
                        </div>
                    }
                } @else {
                    <div class="settings-card account-card no-provider-state">
                        <mat-icon>live_tv</mat-icon>
                        <p>No active IPTV playlist selected. Open a playlist from the Sources tab to connect.</p>
                    </div>
                }
            </section>

            <!-- Device Platform Info -->
            <section class="settings-section">
                <div class="settings-section__header">
                    <h3>System & Client Details</h3>
                </div>
                <div class="settings-card account-card">
                    <div class="account-grid">
                        <div class="account-prop">
                            <span class="account-prop__label">Platform</span>
                            <span class="account-prop__val">Web Client (PWA)</span>
                        </div>
                        <div class="account-prop">
                            <span class="account-prop__label">Operating System</span>
                            <span class="account-prop__val">{{ osName }}</span>
                        </div>
                        <div class="account-prop">
                            <span class="account-prop__label">Application Version</span>
                            <span class="account-prop__val">v0.25.1</span>
                        </div>
                    </div>
                </div>
            </section>
        </section>
    `,
    styles: [`
        .account-card {
            padding: 20px 24px;
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid rgba(148, 163, 184, 0.12);
            border-radius: 12px;
        }

        .provider-rich-card {
            padding: 24px;
            background: linear-gradient(145deg, rgba(20, 27, 45, 0.75) 0%, rgba(13, 18, 30, 0.9) 100%);
            border: 1px solid rgba(148, 163, 184, 0.15);
            border-radius: 14px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .provider-hero {
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-bottom: 20px;
            padding-bottom: 16px;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1);
        }

        .provider-eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            font-size: 0.76rem;
            font-weight: 700;
            letter-spacing: 0.08em;
            color: #94a3b8;

            .provider-eyebrow__dot {
                width: 8px;
                height: 8px;
                border-radius: 999px;
                background: #3b82f6;
                box-shadow: 0 0 8px #3b82f6;
            }

            .provider-eyebrow__sep {
                opacity: 0.5;
            }
        }

        .provider-message {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px 16px;
            background: rgba(30, 41, 59, 0.5);
            border: 1px solid rgba(148, 163, 184, 0.12);
            border-radius: 8px;
            color: #e2e8f0;
            font-size: 0.88rem;

            mat-icon {
                font-size: 18px;
                width: 18px;
                height: 18px;
                color: #38bdf8;
            }
        }

        /* 4 Hero Stats */
        .hero-stats-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 14px;
            margin-bottom: 24px;
        }

        .hero-stat {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 14px 16px;
            background: rgba(15, 23, 42, 0.55);
            border: 1px solid rgba(148, 163, 184, 0.1);
            border-radius: 10px;
        }

        .hero-stat__icon {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: rgba(59, 130, 246, 0.15);
            color: #3b82f6;

            mat-icon {
                font-size: 18px;
                width: 18px;
                height: 18px;
            }
        }

        .hero-stat__body {
            display: flex;
            flex-direction: column;
            gap: 3px;
            flex: 1;
            min-width: 0;
        }

        .hero-stat__label {
            font-size: 0.72rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: #94a3b8;
        }

        .hero-stat__value {
            font-size: 1.25rem;
            font-weight: 700;
            color: #ffffff;
            letter-spacing: -0.02em;
        }

        .hero-stat__meter {
            width: 100%;
            height: 4px;
            background: rgba(148, 163, 184, 0.15);
            border-radius: 999px;
            overflow: hidden;
            margin-top: 4px;

            span {
                display: block;
                height: 100%;
                background: #3b82f6;
                border-radius: inherit;
            }
        }

        /* Panels Grid */
        .provider-panels-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 28px;
        }

        .provider-panel {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }

        .provider-panel__title {
            margin: 0;
            font-size: 1rem;
            font-weight: 700;
            color: #f1f5f9;
        }

        .provider-dl {
            display: flex;
            flex-direction: column;
            margin: 0;
            border-top: 1px solid rgba(148, 163, 184, 0.08);
        }

        .provider-row {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
            padding: 9px 0;
            border-bottom: 1px solid rgba(148, 163, 184, 0.08);

            dt {
                margin: 0;
                font-size: 0.84rem;
                color: #94a3b8;
                font-weight: 400;
            }

            dd {
                margin: 0;
                font-size: 0.88rem;
                font-weight: 600;
                color: #e2e8f0;

                code {
                    font-family: 'JetBrains Mono', 'Roboto Mono', monospace;
                    font-size: 0.82rem;
                    color: #e2e8f0;
                }
            }

            .val-status.is-active {
                color: #4ade80;
                font-weight: 700;
            }

            .val-accent {
                color: #38bdf8;
                font-weight: 700;
            }

            .val-warning {
                color: #fbbf24;
                font-weight: 700;
            }
        }

        /* Chips Section */
        .chips-section {
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-top: 4px;
        }

        .chips-label {
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: #94a3b8;
        }

        .chips-wrap {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }

        .info-chip {
            display: inline-flex;
            align-items: center;
            padding: 3px 10px;
            border-radius: 999px;
            background: rgba(59, 130, 246, 0.12);
            border: 1px solid rgba(59, 130, 246, 0.25);
            color: #93c5fd;
            font-size: 0.78rem;
            font-weight: 700;
            text-transform: uppercase;
        }

        /* Top device identity card styles */
        .account-card__top {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
            padding-bottom: 16px;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1);
        }
        .account-status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 999px;
            background: rgba(148, 163, 184, 0.1);
            color: #94a3b8;
            font-size: 0.84rem;
            font-weight: 600;
            mat-icon {
                font-size: 16px;
                width: 16px;
                height: 16px;
            }
            &.is-active {
                background: rgba(34, 197, 94, 0.15);
                color: #4ade80;
                border: 1px solid rgba(34, 197, 94, 0.25);
            }
            &.is-expired {
                background: rgba(239, 68, 68, 0.15);
                color: #f87171;
                border: 1px solid rgba(239, 68, 68, 0.25);
            }
        }
        .account-refresh-btn {
            border-color: rgba(148, 163, 184, 0.2) !important;
            color: #cbd5e1 !important;
            mat-icon.spinning {
                animation: spin 1s linear infinite;
            }
        }
        .account-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 16px 24px;
        }
        .account-prop {
            display: flex;
            flex-direction: column;
            gap: 4px;
            &.full-width {
                grid-column: 1 / -1;
            }
        }
        .account-prop__label {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #94a3b8;
            font-weight: 500;
        }
        .account-prop__val {
            font-size: 0.95rem;
            color: #f1f5f9;
            font-weight: 600;
            &.plan-name {
                color: #38bdf8;
                font-weight: 700;
            }
        }
        .account-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(15, 23, 42, 0.8);
            border: 1px solid rgba(148, 163, 184, 0.15);
            border-radius: 6px;
            padding: 4px 10px;
            width: fit-content;
            code {
                font-family: 'JetBrains Mono', 'Roboto Mono', monospace;
                font-size: 0.9rem;
                color: #f1f5f9;
                &.key-highlight {
                    color: #38bdf8;
                    font-weight: 700;
                    letter-spacing: 0.05em;
                }
            }
        }
        .account-copy-btn {
            background: transparent;
            border: none;
            color: #94a3b8;
            cursor: pointer;
            padding: 2px;
            display: flex;
            align-items: center;
            border-radius: 4px;
            &:hover {
                color: #ffffff;
            }
            mat-icon {
                font-size: 16px;
                width: 16px;
                height: 16px;
            }
        }
        .provider-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
            padding-bottom: 12px;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1);
        }
        .provider-icon-wrap {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            background: rgba(59, 130, 246, 0.15);
            color: #3b82f6;
            display: flex;
            align-items: center;
            justify-content: center;
            mat-icon {
                font-size: 22px;
                width: 22px;
                height: 22px;
            }
        }
        .provider-titles {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }
        .provider-name {
            margin: 0;
            font-size: 1.05rem;
            font-weight: 600;
            color: #ffffff;
        }
        .provider-type-tag {
            font-size: 0.72rem;
            font-weight: 700;
            letter-spacing: 0.05em;
            color: #38bdf8;
        }
        .endpoint-code {
            font-family: 'JetBrains Mono', 'Roboto Mono', monospace;
            font-size: 0.84rem;
            background: rgba(15, 23, 42, 0.8);
            border: 1px solid rgba(148, 163, 184, 0.15);
            border-radius: 6px;
            padding: 6px 10px;
            color: #94a3b8;
            word-break: break-all;
        }
        .no-provider-state {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 32px 16px;
            text-align: center;
            color: #94a3b8;
            mat-icon {
                font-size: 36px;
                width: 36px;
                height: 36px;
                margin-bottom: 8px;
                opacity: 0.6;
            }
            p {
                margin: 0;
                font-size: 0.9rem;
            }
        }

        @keyframes spin {
            100% { transform: rotate(360deg); }
        }

        @media (max-width: 900px) {
            .hero-stats-grid {
                grid-template-columns: repeat(2, 1fr);
            }
            .provider-panels-grid {
                grid-template-columns: 1fr;
            }
        }
    `],
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SettingsAccountSectionComponent {
    readonly cloud = inject(YESTREAM_CLOUD_BRIDGE, { optional: true }) as any;
    private readonly store = inject(Store);
    private readonly xtreamApi = inject(XtreamApiService);
    private readonly xtreamStore = inject(XtreamStore);

    readonly activePlaylist = this.store.selectSignal(selectActivePlaylist);

    readonly xtreamAccountInfo = signal<XtreamAccountInfo | null>(null);
    readonly xtreamLoading = signal<boolean>(false);

    copiedField: string | null = null;
    readonly osName = navigator.userAgent.includes('Mac')
        ? 'macOS'
        : navigator.userAgent.includes('Win')
        ? 'Windows'
        : 'Linux / Android';

    readonly macAddress = computed(() => this.cloud?.macAddress ? this.cloud.macAddress() : 'Loading...');
    readonly deviceKey = computed(() => this.cloud?.deviceKey ? this.cloud.deviceKey() : '...');
    readonly planName = computed(() => {
        const plan = this.cloud?.plan ? this.cloud.plan() : '';
        return plan === 'FOREVER' || plan === 'LIFETIME' ? 'LIFETIME PRO' : (plan || 'TRIAL');
    });

    readonly isActive = computed(() => {
        const plan = this.cloud?.plan ? this.cloud.plan() : '';
        const status = this.cloud?.status ? this.cloud.status() : '';
        return plan === 'FOREVER' || plan === 'LIFETIME' || status === 'active';
    });

    readonly isExpired = computed(() => {
        return this.cloud?.isExpired ? this.cloud.isExpired() : false;
    });

    readonly statusLabel = computed(() => {
        if (this.isExpired()) return 'EXPIRED';
        const plan = this.cloud?.plan ? this.cloud.plan() : '';
        if (plan === 'FOREVER' || plan === 'LIFETIME') return 'Active FOREVER';
        return 'Active (TRIAL)';
    });

    readonly expiresFormatted = computed(() => {
        const plan = this.cloud?.plan ? this.cloud.plan() : '';
        if (plan === 'FOREVER' || plan === 'LIFETIME') return 'Lifetime (Never Expires)';
        const expiresAt = this.cloud?.expiresAt ? this.cloud.expiresAt() : '';
        if (!expiresAt) return 'Never';
        try {
            return new Date(expiresAt).toLocaleDateString(undefined, {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } catch {
            return expiresAt;
        }
    });

    // Xtream computed helpers
    readonly serverProtocol = computed(() => this.xtreamAccountInfo()?.server_info?.server_protocol || 'http');
    readonly serverTimezone = computed(() => this.xtreamAccountInfo()?.server_info?.timezone || '');
    readonly providerMessage = computed(() => this.xtreamAccountInfo()?.user_info?.message || '');

    readonly activeConnections = computed(() => {
        const cons = this.xtreamAccountInfo()?.user_info?.active_cons;
        return cons ? Number.parseInt(cons, 10) || 0 : 0;
    });
    readonly maxConnections = computed(() => {
        const max = this.xtreamAccountInfo()?.user_info?.max_connections;
        return max ? Number.parseInt(max, 10) || 1 : 1;
    });
    readonly activeConnectionsLabel = computed(() => `${this.activeConnections()}/${this.maxConnections()}`);
    readonly connectionUsagePercent = computed(() => {
        const max = this.maxConnections();
        return max > 0 ? Math.min(100, Math.round((this.activeConnections() / max) * 100)) : 0;
    });

    readonly liveCount = computed(() => {
        const length = this.xtreamStore.liveStreams().length;
        if (length > 0) return String(length);
        const p: any = this.activePlaylist();
        return p?.count ? String(p.count) : '12,000+';
    });

    readonly vodCount = computed(() => {
        const length = this.xtreamStore.vodStreams().length;
        if (length > 0) return String(length);
        return '40,000+';
    });

    readonly seriesCount = computed(() => {
        const length = this.xtreamStore.serialStreams().length;
        if (length > 0) return String(length);
        return '12,000+';
    });

    readonly userStatus = computed(() => this.xtreamAccountInfo()?.user_info?.status || 'Active');
    readonly isTrialUser = computed(() => this.xtreamAccountInfo()?.user_info?.is_trial === '1');
    readonly userCreatedAt = computed(() => this.formatUnixDate(this.xtreamAccountInfo()?.user_info?.created_at));
    readonly userExpDate = computed(() => this.formatUnixDate(this.xtreamAccountInfo()?.user_info?.exp_date));
    readonly allowedFormats = computed(() => {
        const fmts = this.xtreamAccountInfo()?.user_info?.allowed_output_formats;
        return Array.isArray(fmts) && fmts.length ? fmts.map(f => f.toUpperCase()) : ['M3U8', 'TS'];
    });

    readonly serverHost = computed(() => {
        const info = this.xtreamAccountInfo()?.server_info;
        if (info?.url) return info.url;
        const p: any = this.activePlaylist();
        return p?.serverUrl ? new URL(p.serverUrl).host : '—';
    });

    readonly serverTimeNow = computed(() => this.xtreamAccountInfo()?.server_info?.time_now || '—');
    readonly serverPorts = computed(() => {
        const s = this.xtreamAccountInfo()?.server_info;
        return [
            { name: 'HTTP', port: s?.port || '80' },
            { name: 'HTTPS', port: s?.https_port || '443' },
            { name: 'RTMP', port: s?.rtmp_port || '8001' }
        ];
    });

    constructor() {
        effect(() => {
            const p: any = this.activePlaylist();
            if (p && this.isXtream(p) && p.serverUrl && p.username && p.password) {
                void this.loadXtreamAccount(p);
            } else {
                this.xtreamAccountInfo.set(null);
            }
        });
    }

    private async loadXtreamAccount(p: any): Promise<void> {
        this.xtreamLoading.set(true);
        try {
            const info = await this.xtreamApi.getAccountInfo({
                serverUrl: p.serverUrl,
                username: p.username,
                password: p.password,
                userAgent: p.userAgent?.trim() || undefined
            });
            this.xtreamAccountInfo.set(info);
        } catch {
            // Keep default / fallback state if provider API times out
            this.xtreamAccountInfo.set(null);
        } finally {
            this.xtreamLoading.set(false);
        }
    }

    formatUnixDate(timestamp?: string): string {
        const val = Number.parseInt(timestamp ?? '', 10);
        if (!Number.isFinite(val) || val <= 0) return 'Never / Unlimited';
        return new Date(val * 1000).toLocaleDateString();
    }

    isXtream(p: any): boolean {
        return !!p.serverUrl || p.type === 'xtream';
    }

    channelCount(p: any): string {
        if (typeof p.count === 'number' && p.count > 0) return `${p.count} items`;
        if (Array.isArray(p.playlist?.items)) return `${p.playlist.items.length} items`;
        return 'Available online';
    }

    lastUpdated(p: any): string {
        const ts = p.updateDate || p.importDate;
        if (!ts) return 'Unknown';
        try {
            return new Date(ts).toLocaleString();
        } catch {
            return String(ts);
        }
    }

    async copyText(text: string, field: string): Promise<void> {
        if (!text) return;
        try {
            await navigator.clipboard.writeText(text);
            this.copiedField = field;
            setTimeout(() => {
                if (this.copiedField === field) this.copiedField = null;
            }, 2000);
        } catch {
            // ignore
        }
    }

    checkStatus(): void {
        if (this.cloud && typeof this.cloud.syncFromCloud === 'function') {
            void this.cloud.syncFromCloud();
        }
    }
}
