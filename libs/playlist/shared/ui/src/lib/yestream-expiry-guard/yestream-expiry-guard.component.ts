import { Component, inject, computed, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
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
        @if (isExpired() && !isDismissed()) {
            <div class="tv-expiry-lockscreen" role="alertdialog" aria-modal="true" aria-label="Subscription Expired">
                <div class="expiry-luxury-container">
                    <!-- 1. BRAND HEADER (Authentic origami bird logo + Yestream) -->
                    <div class="expiry-brand-header">
                        <img
                            [src]="logoSrc()"
                            (error)="onLogoError()"
                            alt="Yestream"
                            class="expiry-brand-logo"
                            width="52"
                            height="52"
                        />
                        <div class="expiry-brand-text">
                            <span class="brand-title">YESTREAM</span>
                            <span class="brand-subtitle">PRO IPTV PLAYER</span>
                        </div>
                    </div>

                    <!-- 2. EXPIRED BANNER -->
                    <div class="expiry-alert-header">
                        <div class="expiry-alert-title">
                            <span class="hourglass-icon">⏳</span>
                            <h2>Your trial period has expired.</h2>
                        </div>
                        <p class="expiry-alert-subtitle">
                            To continue enjoying Live TV, Movies, Series, and the EPG Timeline, please renew or activate your device.
                        </p>
                    </div>

                    <!-- 3. ACTIVATION HERO CARD (Split Screen: QR Code + Credentials) -->
                    <div class="expiry-card-split">
                        <!-- Left: QR Code -->
                        <div class="expiry-qr-col">
                            <div class="qr-white-card">
                                <qrcode
                                    [qrdata]="qrCodeData()"
                                    [width]="176"
                                    [errorCorrectionLevel]="'M'"
                                    [margin]="1"
                                    [colorLight]="'#ffffff'"
                                    [colorDark]="'#04060b'"
                                ></qrcode>
                            </div>
                            <span class="qr-scan-hint">Scan with phone to activate</span>
                        </div>

                        <div class="expiry-divider"></div>

                        <!-- Right: Hardware MAC + Activation Key + Portal URL -->
                        <div class="expiry-details-col">
                            <div class="cred-field-group">
                                <span class="field-label">DEVICE MAC ADDRESS</span>
                                <div class="field-value-pill mac-pill">
                                    <code>{{ mac() || 'DA:E5:4A:7C:18:3F' }}</code>
                                    <button
                                        type="button"
                                        class="copy-btn"
                                        (click)="copyText(mac() || 'DA:E5:4A:7C:18:3F', 'mac')"
                                        title="Copy MAC"
                                    >
                                        <mat-icon>{{ copiedField === 'mac' ? 'check' : 'content_copy' }}</mat-icon>
                                    </button>
                                </div>
                            </div>

                            <div class="cred-field-group">
                                <span class="field-label">DEVICE ACTIVATION KEY</span>
                                <div class="field-value-pill key-pill">
                                    <code class="key-value">{{ key() || '187828' }}</code>
                                    <button
                                        type="button"
                                        class="copy-btn"
                                        (click)="copyText(key() || '187828', 'key')"
                                        title="Copy Key"
                                    >
                                        <mat-icon>{{ copiedField === 'key' ? 'check' : 'content_copy' }}</mat-icon>
                                    </button>
                                </div>
                            </div>

                            <div class="cred-field-group">
                                <span class="field-label">PORTAL URL</span>
                                <a
                                    href="https://yestream.ai.studio/"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    class="portal-url-text"
                                >
                                    <span>https://yestream.ai.studio/</span>
                                    <mat-icon class="external-icon">open_in_new</mat-icon>
                                </a>
                            </div>
                        </div>
                    </div>

                    <!-- 4. ACTION BUTTONS: Refresh Status & Manage Playlists -->
                    <div class="expiry-action-row">
                        <button
                            mat-flat-button
                            type="button"
                            class="expiry-btn primary-refresh"
                            [disabled]="isLoading()"
                            (click)="checkAndUnlock()"
                        >
                            <mat-icon [class.spinning]="isLoading()">sync</mat-icon>
                            <span>{{ isLoading() ? 'Checking…' : '↻ Refresh Status' }}</span>
                        </button>

                        <button
                            mat-button
                            type="button"
                            class="expiry-btn secondary-playlists"
                            (click)="managePlaylists()"
                        >
                            <mat-icon>list_alt</mat-icon>
                            <span>Manage Playlists</span>
                        </button>
                    </div>

                    <!-- 5. FEEDBACK NOTICE -->
                    @if (checkNotice()) {
                        <p class="expiry-result-msg" role="status">
                            {{ checkNotice() }}
                        </p>
                    }
                </div>
            </div>
        } @else if (isExpired() && isDismissed()) {
            <!-- Mini sticky banner allowing user to reopen expiry guard while managing playlists -->
            <div class="expiry-mini-banner">
                <div class="banner-left">
                    <span class="banner-warn">⏳ Subscription Expired:</span>
                    <span class="banner-hint">Device streams are locked until renewed.</span>
                </div>
                <button type="button" class="banner-reopen-btn" (click)="isDismissed.set(false)">
                    View Activation & QR
                </button>
            </div>
        }
    `,
    styles: [`
        :host {
            display: contents;
        }

        .tv-expiry-lockscreen {
            position: fixed;
            inset: 0;
            z-index: 10000;
            display: flex;
            align-items: center;
            justify-content: center;
            background: radial-gradient(ellipse at 50% 25%, #151c2e 0%, #07090e 85%);
            backdrop-filter: blur(24px);
            padding: 30px;
            animation: fadeIn 0.25s ease-out;
            overflow-y: auto;
            box-sizing: border-box;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        }

        .expiry-luxury-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            max-width: 860px;
            width: 100%;
            margin: auto;
        }

        /* 1. BRAND HEADER */
        .expiry-brand-header {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 16px;
            margin-bottom: 24px;
        }

        .expiry-brand-logo {
            width: 52px;
            height: 52px;
            object-fit: contain;
            filter: drop-shadow(0 2px 10px rgba(56, 189, 248, 0.25));
        }

        .expiry-brand-text {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
            text-align: left;
        }

        .expiry-brand-text .brand-title {
            font-size: 32px;
            font-weight: 900;
            letter-spacing: 2.5px;
            color: #ffffff;
            line-height: 1;
        }

        .expiry-brand-text .brand-subtitle {
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 3px;
            color: #38bdf8;
            font-family: monospace;
            margin-top: 5px;
        }

        /* 2. ALERT BANNER */
        .expiry-alert-header {
            margin-bottom: 28px;
        }

        .expiry-alert-title {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin-bottom: 8px;
        }

        .expiry-alert-title .hourglass-icon {
            font-size: 24px;
            line-height: 1;
        }

        .expiry-alert-title h2 {
            font-size: 26px;
            font-weight: 700;
            color: #ffffff;
            margin: 0;
            letter-spacing: -0.01em;
        }

        .expiry-alert-subtitle {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.72);
            margin: 0;
            max-width: 660px;
            line-height: 1.5;
        }

        /* 3. HERO SPLIT CARD */
        .expiry-card-split {
            display: flex;
            align-items: center;
            background: #0f172a;
            border: 1.5px solid rgba(255, 255, 255, 0.12);
            border-radius: 20px;
            padding: 32px 48px;
            gap: 40px;
            box-shadow: 0 24px 60px rgba(0, 0, 0, 0.65), 0 0 40px rgba(15, 23, 42, 0.8);
            margin-bottom: 32px;
            width: 100%;
            max-width: 780px;
            box-sizing: border-box;
        }

        .expiry-qr-col {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 12px;
            flex-shrink: 0;
        }

        .qr-white-card {
            background: #ffffff;
            border-radius: 16px;
            padding: 10px;
            width: 196px;
            height: 196px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.45);
            box-sizing: border-box;
        }

        .qr-loading-box {
            color: #0f172a;
            font-size: 13px;
            font-weight: 600;
        }

        .qr-scan-hint {
            font-size: 12px;
            font-weight: 700;
            color: rgba(255, 255, 255, 0.75);
            letter-spacing: 0.02em;
        }

        .expiry-divider {
            width: 1px;
            height: 200px;
            background: rgba(255, 255, 255, 0.12);
            flex-shrink: 0;
        }

        .expiry-details-col {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
            text-align: left;
            gap: 16px;
            flex: 1;
            min-width: 0;
        }

        .cred-field-group {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
            gap: 6px;
            width: 100%;
        }

        .cred-field-group .field-label {
            font-size: 11px;
            font-weight: 700;
            font-family: monospace;
            color: rgba(255, 255, 255, 0.5);
            letter-spacing: 1px;
        }

        .field-value-pill {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 8px 16px;
            background: rgba(255, 255, 255, 0.07);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 8px;
            width: 100%;
            box-sizing: border-box;

            code {
                font-family: 'JetBrains Mono', 'Roboto Mono', monospace;
                font-size: 18px;
                font-weight: 700;
                letter-spacing: 1px;
                color: #ffffff;
            }

            .key-value {
                color: #38bdf8;
                letter-spacing: 2px;
            }
        }

        .copy-btn {
            background: transparent;
            border: none;
            color: rgba(255, 255, 255, 0.6);
            cursor: pointer;
            padding: 4px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-radius: 4px;
            transition: color 0.15s, background-color 0.15s;

            &:hover {
                color: #ffffff;
                background: rgba(255, 255, 255, 0.1);
            }

            mat-icon {
                font-size: 18px;
                width: 18px;
                height: 18px;
            }
        }

        .portal-url-text {
            font-size: 13px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.75);
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 4px;

            &:hover {
                color: #38bdf8;
                text-decoration: underline;
            }

            .external-icon {
                font-size: 14px;
                width: 14px;
                height: 14px;
            }
        }

        /* 4. ACTION BUTTONS */
        .expiry-action-row {
            display: flex;
            gap: 20px;
            align-items: center;
            justify-content: center;
            width: 100%;
        }

        .expiry-btn {
            height: 48px;
            padding: 0 28px;
            min-width: 190px;
            font-size: 15px;
            font-weight: 700;
            border-radius: 12px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            transition: all 0.18s ease;

            mat-icon {
                font-size: 19px;
                width: 19px;
                height: 19px;
            }
        }

        .expiry-btn.primary-refresh {
            background: #0284c7;
            color: #ffffff;
            border: none;
            box-shadow: 0 4px 14px rgba(2, 132, 199, 0.45);

            &:hover:not([disabled]) {
                background: #0369a1;
                transform: translateY(-1px);
                box-shadow: 0 6px 18px rgba(2, 132, 199, 0.55);
            }

            .spinning {
                animation: spin 1s linear infinite;
            }
        }

        .expiry-btn.secondary-playlists {
            background: rgba(255, 255, 255, 0.08);
            color: #ffffff;
            border: 1px solid rgba(255, 255, 255, 0.2);

            &:hover {
                background: rgba(255, 255, 255, 0.18);
                border-color: #38bdf8;
                color: #ffffff;
                transform: translateY(-1px);
            }
        }

        /* 5. RESULT MESSAGE */
        .expiry-result-msg {
            margin-top: 20px;
            font-size: 14px;
            font-weight: 600;
            color: #38bdf8;
            animation: fadeIn 0.2s ease;
        }

        /* MINI STICKY BANNER */
        .expiry-mini-banner {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 9999;
            background: linear-gradient(90deg, #b91c1c 0%, #1e1b4b 100%);
            color: #ffffff;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 24px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
            font-size: 13px;
        }

        .banner-left {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .banner-warn {
            font-weight: 800;
            letter-spacing: 0.02em;
        }

        .banner-hint {
            color: rgba(255, 255, 255, 0.85);
        }

        .banner-reopen-btn {
            background: #ffffff;
            color: #0f172a;
            border: none;
            padding: 6px 14px;
            border-radius: 6px;
            font-weight: 700;
            font-size: 12px;
            cursor: pointer;
            transition: background-color 0.15s;

            &:hover {
                background: #e2e8f0;
            }
        }

        @keyframes spin {
            100% { transform: rotate(360deg); }
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: scale(0.98); }
            to { opacity: 1; transform: scale(1); }
        }

        @media (max-width: 640px) {
            .expiry-card-split {
                flex-direction: column;
                padding: 24px 20px;
                gap: 24px;
            }

            .expiry-divider {
                width: 100%;
                height: 1px;
            }

            .expiry-action-row {
                flex-direction: column;
            }

            .expiry-btn {
                width: 100%;
            }
        }
    `],
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class YestreamExpiryGuardComponent {
    private readonly router = inject(Router);
    readonly cloud = inject(YESTREAM_CLOUD_BRIDGE, { optional: true }) as any;

    readonly isExpired = computed(() => {
        return this.cloud?.isExpired ? this.cloud.isExpired() : false;
    });

    readonly mac = computed(() => (this.cloud?.macAddress ? this.cloud.macAddress() : ''));
    readonly key = computed(() => (this.cloud?.deviceKey ? this.cloud.deviceKey() : ''));
    readonly portalUrl = 'https://yestream.ai.studio/';
    readonly qrCodeData = computed(() =>
        this.cloud?.portalLoginUrl && this.cloud.portalLoginUrl()
            ? this.cloud.portalLoginUrl()
            : 'https://yestream.ai.studio/'
    );
    readonly isLoading = computed(() => {
        return this.cloud?.syncLoading ? this.cloud.syncLoading() : false;
    });

    readonly isDismissed = signal(false);
    readonly checkNotice = signal<string | null>(null);
    readonly logoSrc = signal('assets/logo.png');
    copiedField: string | null = null;

    onLogoError(): void {
        if (this.logoSrc() === 'assets/logo.png') {
            this.logoSrc.set('logo.png');
        }
    }

    managePlaylists(): void {
        this.isDismissed.set(true);
        void this.router.navigate(['/workspace/sources']);
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

    async checkAndUnlock(): Promise<void> {
        if (!this.cloud || typeof this.cloud.syncFromCloud !== 'function') return;
        this.checkNotice.set(null);

        await this.cloud.syncFromCloud();

        if (this.cloud.isExpired && !this.cloud.isExpired()) {
            this.isDismissed.set(true);
            this.checkNotice.set('Subscription successfully renewed! Unlocking…');
        } else {
            this.checkNotice.set('Subscription is still expired. Please complete renewal above.');
        }
    }
}
