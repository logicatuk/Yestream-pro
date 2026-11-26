import { Component, inject, computed, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { QRCodeComponent } from 'angularx-qrcode';
import { TranslateModule } from '@ngx-translate/core';
import { YESTREAM_CLOUD_BRIDGE } from '@iptvnator/services';

@Component({
    selector: 'app-yestream-expiry-guard',
    standalone: true,
    imports: [CommonModule, MatButtonModule, MatIconModule, QRCodeComponent, TranslateModule],
    template: `
        @if (isExpired()) {
            <div class="expiry-overlay" role="alertdialog" aria-modal="true">
                <div class="expiry-card">
                    <!-- Brand header with Yestream logo -->
                    <div class="expiry-brand-header">
                        <img src="assets/logo.png" alt="Yestream" class="expiry-brand-logo" />
                        <div class="expiry-brand-text">
                            <span class="brand-title">YESTREAM</span>
                            <span class="brand-subtitle">PRO IPTV PLAYER</span>
                        </div>
                    </div>

                    <!-- Glow header -->
                    <div class="expiry-badge">
                        <mat-icon>hourglass_bottom</mat-icon>
                        <span>{{ 'YESTREAM.SUBSCRIPTION_EXPIRED' | translate }}</span>
                    </div>

                    <h1 class="expiry-title">Your trial period has expired.</h1>
                    <p class="expiry-desc">
                        To continue enjoying Live TV, Movies, Series, and the EPG Timeline, please renew or activate your device.
                    </p>

                    <!-- Credentials & QR Code Grid -->
                    <div class="expiry-grid">
                        <div class="expiry-qr-col">
                            <div class="expiry-qr-frame">
                                @if (portalUrl()) {
                                    <qrcode
                                        [qrdata]="portalUrl()"
                                        [width]="130"
                                        [errorCorrectionLevel]="'M'"
                                        [margin]="2"
                                        [colorLight]="'#ffffff'"
                                        [colorDark]="'#090d16'"
                                    ></qrcode>
                                } @else {
                                    <div class="expiry-qr-placeholder">
                                        <mat-icon>qr_code_2</mat-icon>
                                    </div>
                                }
                            </div>
                            <span class="expiry-qr-hint">{{ 'YESTREAM.SCAN_TO_RENEW' | translate }}</span>
                        </div>

                        <div class="expiry-info-col">
                            <div class="expiry-field">
                                <span class="expiry-field-label">{{ 'YESTREAM.MAC_ADDRESS' | translate }}</span>
                                <div class="expiry-field-pill">
                                    <code>{{ mac() }}</code>
                                    <button
                                        type="button"
                                        class="copy-btn"
                                        (click)="copyText(mac(), 'mac')"
                                        [title]="'YESTREAM.COPY_MAC' | translate"
                                    >
                                        <mat-icon>{{ copiedField === 'mac' ? 'check' : 'content_copy' }}</mat-icon>
                                    </button>
                                </div>
                            </div>

                            <div class="expiry-field">
                                <span class="expiry-field-label">{{ 'YESTREAM.DEVICE_KEY' | translate }}</span>
                                <div class="expiry-field-pill">
                                    <code class="key-pill">{{ key() }}</code>
                                    <button
                                        type="button"
                                        class="copy-btn"
                                        (click)="copyText(key(), 'key')"
                                        [title]="'YESTREAM.COPY_KEY' | translate"
                                    >
                                        <mat-icon>{{ copiedField === 'key' ? 'check' : 'content_copy' }}</mat-icon>
                                    </button>
                                </div>
                            </div>

                            <div class="expiry-field">
                                <span class="expiry-field-label">{{ 'YESTREAM.WEB_PORTAL' | translate }}</span>
                                <a [href]="portalUrl()" target="_blank" rel="noopener noreferrer" class="portal-link">
                                    <span>yestream.ai.studio</span>
                                    <mat-icon>open_in_new</mat-icon>
                                </a>
                            </div>
                        </div>
                    </div>

                    <!-- Feedback notice if user checked status but still expired -->
                    @if (checkNotice()) {
                        <div class="expiry-notice" [class.is-warning]="!isUnlocked()">
                            <mat-icon>info</mat-icon>
                            <span>{{ checkNotice() }}</span>
                        </div>
                    }

                    <!-- Actions -->
                    <div class="expiry-actions">
                        <button
                            mat-flat-button
                            type="button"
                            class="unlock-btn"
                            [disabled]="isLoading()"
                            (click)="checkAndUnlock()"
                        >
                            <mat-icon [class.spinning]="isLoading()">sync</mat-icon>
                            <span>{{ (isLoading() ? 'YESTREAM.CHECKING_SERVER' : 'YESTREAM.CHECK_STATUS_UNLOCK') | translate }}</span>
                        </button>
                    </div>
                </div>
            </div>
        }
    `,
    styles: [`
        .expiry-overlay {
            position: fixed;
            inset: 0;
            z-index: 10000;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(8, 12, 22, 0.92);
            backdrop-filter: blur(20px);
            padding: 24px;
            animation: fadeIn 0.3s ease;
        }

        .expiry-card {
            position: relative;
            max-width: 540px;
            width: 100%;
            background: linear-gradient(145deg, rgba(26, 32, 48, 0.95) 0%, rgba(13, 17, 28, 0.98) 100%);
            border: 1px solid rgba(239, 68, 68, 0.35);
            box-shadow: 0 0 60px rgba(239, 68, 68, 0.2), 0 25px 50px -12px rgba(0, 0, 0, 0.6);
            border-radius: 20px;
            padding: 32px 36px;
            text-align: center;
            color: #f1f5f9;
        }

        .expiry-brand-header {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 14px;
            margin-bottom: 22px;
        }

        .expiry-brand-logo {
            width: 46px;
            height: 46px;
            object-fit: contain;
        }

        .expiry-brand-text {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
            text-align: left;
        }

        .expiry-brand-text .brand-title {
            font-size: 26px;
            font-weight: 900;
            letter-spacing: 2px;
            color: #ffffff;
            line-height: 1;
        }

        .expiry-brand-text .brand-subtitle {
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 2.5px;
            color: #38bdf8;
            font-family: monospace;
            margin-top: 3px;
        }

        .expiry-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 999px;
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #f87171;
            font-size: 0.78rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            margin-bottom: 16px;

            mat-icon {
                font-size: 15px;
                width: 15px;
                height: 15px;
            }
        }

        .expiry-title {
            margin: 0 0 8px;
            font-size: 1.6rem;
            font-weight: 800;
            letter-spacing: -0.02em;
            color: #ffffff;
        }

        .expiry-desc {
            margin: 0 0 24px;
            font-size: 0.92rem;
            line-height: 1.55;
            color: #94a3b8;
        }

        .expiry-grid {
            display: flex;
            align-items: center;
            gap: 28px;
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid rgba(148, 163, 184, 0.1);
            border-radius: 14px;
            padding: 20px;
            margin-bottom: 20px;
            text-align: left;
        }

        .expiry-qr-col {
            display: flex;
            flex-direction: column;
            align-items: center;
            flex-shrink: 0;
        }

        .expiry-qr-frame {
            padding: 6px;
            background: #ffffff;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }

        .expiry-qr-placeholder {
            width: 130px;
            height: 130px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #1e293b;
            color: #64748b;
        }

        .expiry-qr-hint {
            margin-top: 8px;
            font-size: 0.72rem;
            color: #94a3b8;
            font-weight: 500;
        }

        .expiry-info-col {
            display: flex;
            flex-direction: column;
            gap: 12px;
            flex: 1;
            min-width: 0;
        }

        .expiry-field {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .expiry-field-label {
            font-size: 0.72rem;
            text-transform: uppercase;
            font-weight: 600;
            letter-spacing: 0.06em;
            color: #94a3b8;
        }

        .expiry-field-pill {
            display: inline-flex;
            align-items: center;
            justify-content: space-between;
            padding: 4px 10px;
            background: rgba(15, 23, 42, 0.85);
            border: 1px solid rgba(148, 163, 184, 0.18);
            border-radius: 8px;

            code {
                font-family: 'JetBrains Mono', 'Roboto Mono', monospace;
                font-size: 0.86rem;
                font-weight: 700;
                color: #e2e8f0;
            }

            .key-pill {
                color: #38bdf8;
                letter-spacing: 0.08em;
            }
        }

        .copy-btn {
            background: transparent;
            border: none;
            color: #94a3b8;
            cursor: pointer;
            padding: 3px;
            display: flex;
            align-items: center;
            border-radius: 4px;
            transition: color 0.15s;

            &:hover {
                color: #ffffff;
            }

            mat-icon {
                font-size: 15px;
                width: 15px;
                height: 15px;
            }
        }

        .portal-link {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            color: #38bdf8;
            font-size: 0.86rem;
            font-weight: 600;
            text-decoration: none;
            &:hover {
                text-decoration: underline;
                color: #7dd3fc;
            }
            mat-icon {
                font-size: 14px;
                width: 14px;
                height: 14px;
            }
        }

        .expiry-notice {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 14px;
            border-radius: 8px;
            background: rgba(245, 158, 11, 0.15);
            border: 1px solid rgba(245, 158, 11, 0.3);
            color: #fbbf24;
            font-size: 0.84rem;
            margin-bottom: 20px;
            text-align: left;

            mat-icon {
                font-size: 17px;
                width: 17px;
                height: 17px;
                flex-shrink: 0;
            }
        }

        .expiry-actions {
            margin-top: 8px;
        }

        .unlock-btn {
            width: 100%;
            height: 48px;
            font-size: 0.96rem;
            font-weight: 700;
            border-radius: 10px;
            background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(37, 99, 235, 0.35);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;

            &:hover:not([disabled]) {
                background: linear-gradient(135deg, #1d4ed8 0%, #1e40af 100%);
            }

            mat-icon {
                font-size: 20px;
                width: 20px;
                height: 20px;
            }

            .spinning {
                animation: spin 1s linear infinite;
            }
        }

        @keyframes spin {
            100% { transform: rotate(360deg); }
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
    `],
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class YestreamExpiryGuardComponent {
    readonly cloud = inject(YESTREAM_CLOUD_BRIDGE, { optional: true }) as any;

    readonly isExpired = computed(() => {
        return this.cloud?.isExpired ? this.cloud.isExpired() : false;
    });

    readonly mac = computed(() => (this.cloud?.macAddress ? this.cloud.macAddress() : ''));
    readonly key = computed(() => (this.cloud?.deviceKey ? this.cloud.deviceKey() : ''));
    readonly portalUrl = computed(() =>
        this.cloud?.portalLoginUrl ? this.cloud.portalLoginUrl() : 'https://yestream.ai.studio'
    );
    readonly isLoading = computed(() => {
        return this.cloud?.syncLoading ? this.cloud.syncLoading() : false;
    });

    readonly isUnlocked = signal(false);
    readonly checkNotice = signal<string | null>(null);
    copiedField: string | null = null;

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

    async checkAndUnlock(): Promise<void> {
        if (!this.cloud || typeof this.cloud.syncFromCloud !== 'function') return;
        this.checkNotice.set(null);

        await this.cloud.syncFromCloud();

        if (this.cloud.isExpired && !this.cloud.isExpired()) {
            this.isUnlocked.set(true);
            this.checkNotice.set('Subscription successfully renewed! Unlocking...');
        } else {
            this.checkNotice.set(
                'Device is still marked expired on the reseller server. Please ensure your reseller has activated your MAC.'
            );
        }
    }
}
