import {
    ChangeDetectionStrategy,
    Component,
    computed,
    inject,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { Store } from '@ngrx/store';
import { selectActivePlaylist } from '@iptvnator/m3u-state';
import { YESTREAM_CLOUD_BRIDGE } from '@iptvnator/services';

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
                </div>
                <div class="settings-card account-card">
                    @if (activePlaylist(); as p) {
                        <div class="provider-details">
                            <div class="provider-header">
                                <div class="provider-icon-wrap">
                                    <mat-icon>{{ isXtream(p) ? 'cloud' : 'playlist_play' }}</mat-icon>
                                </div>
                                <div class="provider-titles">
                                    <h4 class="provider-name">{{ p.title || p.filename || 'Untitled Playlist' }}</h4>
                                    <span class="provider-type-tag">{{ isXtream(p) ? 'XTREAM CODES' : 'M3U PLAYLIST' }}</span>
                                </div>
                            </div>

                            <div class="account-grid">
                                <div class="account-prop full-width">
                                    <span class="account-prop__label">Server / Endpoint</span>
                                    <code class="endpoint-code">{{ p.serverUrl || p.url || '—' }}</code>
                                </div>

                                @if (isXtream(p)) {
                                    <div class="account-prop">
                                        <span class="account-prop__label">Username</span>
                                        <span class="account-prop__val">{{ p.username || '—' }}</span>
                                    </div>
                                }

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
                    } @else {
                        <div class="no-provider-state">
                            <mat-icon>live_tv</mat-icon>
                            <p>No active IPTV playlist selected. Open a playlist from the Sources tab to connect.</p>
                        </div>
                    }
                </div>
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
            gap: 8px;
            padding: 6px 14px;
            border-radius: 999px;
            font-size: 0.85rem;
            font-weight: 600;
            background: rgba(56, 189, 248, 0.12);
            color: #38bdf8;
            border: 1px solid rgba(56, 189, 248, 0.3);

            mat-icon {
                font-size: 18px;
                width: 18px;
                height: 18px;
            }
            &.is-active {
                background: rgba(34, 197, 94, 0.12);
                color: #4ade80;
                border-color: rgba(34, 197, 94, 0.3);
            }
            &.is-expired {
                background: rgba(239, 68, 68, 0.12);
                color: #f87171;
                border-color: rgba(239, 68, 68, 0.3);
            }
        }
        .account-refresh-btn {
            border-radius: 8px;
            font-size: 0.82rem;
            color: #94a3b8;
            mat-icon {
                font-size: 16px;
                width: 16px;
                height: 16px;
                margin-right: 4px;
            }
            .spinning {
                animation: spin 1s linear infinite;
            }
        }
        @keyframes spin {
            100% { transform: rotate(360deg); }
        }
        .account-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 18px;
        }
        .account-prop {
            display: flex;
            flex-direction: column;
            gap: 6px;
            &.full-width {
                grid-column: 1 / -1;
            }
        }
        .account-prop__label {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #94a3b8;
            font-weight: 600;
        }
        .account-prop__val {
            font-size: 0.95rem;
            color: #f1f5f9;
            font-weight: 500;
        }
        .plan-name {
            color: #a78bfa;
            font-weight: 600;
        }
        .account-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(148, 163, 184, 0.15);
            padding: 6px 12px;
            border-radius: 8px;
            width: fit-content;
            code {
                font-size: 0.95rem;
                font-family: ui-monospace, SFMono-Regular, monospace;
                color: #38bdf8;
                font-weight: 600;
                letter-spacing: 0.05em;
            }
            .key-highlight {
                color: #fbbf24;
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
            justify-content: center;
            border-radius: 4px;
            transition: color 0.15s ease;
            mat-icon {
                font-size: 16px;
                width: 16px;
                height: 16px;
            }
            &:hover {
                color: #f8fafc;
            }
        }
        .provider-header {
            display: flex;
            align-items: center;
            gap: 14px;
            margin-bottom: 18px;
            padding-bottom: 14px;
            border-bottom: 1px solid rgba(148, 163, 184, 0.08);
        }
        .provider-icon-wrap {
            width: 42px;
            height: 42px;
            border-radius: 10px;
            background: linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(168, 85, 247, 0.2));
            border: 1px solid rgba(168, 85, 247, 0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #c084fc;
            mat-icon {
                font-size: 22px;
                width: 22px;
                height: 22px;
            }
        }
        .provider-titles {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .provider-name {
            margin: 0;
            font-size: 1.05rem;
            font-weight: 600;
            color: #f8fafc;
        }
        .provider-type-tag {
            font-size: 0.72rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #38bdf8;
            background: rgba(56, 189, 248, 0.1);
            padding: 2px 8px;
            border-radius: 4px;
            width: fit-content;
        }
        .endpoint-code {
            font-size: 0.82rem;
            font-family: ui-monospace, SFMono-Regular, monospace;
            background: rgba(0, 0, 0, 0.3);
            padding: 6px 10px;
            border-radius: 6px;
            color: #cbd5e1;
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
    `],
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SettingsAccountSectionComponent {
    readonly cloud = inject(YESTREAM_CLOUD_BRIDGE, { optional: true }) as any;
    private readonly store = inject(Store);

    readonly activePlaylist = this.store.selectSignal(selectActivePlaylist);

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
