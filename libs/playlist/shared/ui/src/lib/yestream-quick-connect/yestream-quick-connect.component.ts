import { Component, inject, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { QRCodeComponent } from 'angularx-qrcode';
import { TranslateModule } from '@ngx-translate/core';
import { YESTREAM_CLOUD_BRIDGE } from '@iptvnator/services';

@Component({
    selector: 'app-yestream-quick-connect',
    standalone: true,
    imports: [CommonModule, MatButtonModule, MatIconModule, QRCodeComponent, TranslateModule],
    template: `
        @if (cloud) {
            <div class="yqc-card">
                <div class="yqc-header">
                    <div class="yqc-badge">
                        <mat-icon>devices</mat-icon>
                        <span>{{ 'YESTREAM.CLOUD_CONNECT' | translate }}</span>
                    </div>

                </div>

                <div class="yqc-body">
                    <div class="yqc-qr-wrap">
                        @if (cloud.portalLoginUrl && cloud.portalLoginUrl()) {
                            <qrcode
                                [qrdata]="cloud.portalLoginUrl()"
                                [width]="224"
                                [errorCorrectionLevel]="'M'"
                                [margin]="4"
                                [colorLight]="'#ffffff'"
                                [colorDark]="'#0f172a'"
                            ></qrcode>
                        } @else {
                            <div class="yqc-qr-placeholder">
                                <mat-icon>qr_code_2</mat-icon>
                            </div>
                        }
                        <span class="yqc-qr-caption">{{ 'YESTREAM.SCAN_UPLOAD_PLAYLISTS' | translate }}</span>
                    </div>

                    <div class="yqc-details">
                        <div class="yqc-row">
                            <span class="yqc-label">{{ 'YESTREAM.MAC_ADDRESS' | translate }}</span>
                            <div class="yqc-value-pill">
                                <code>{{ cloud.macAddress ? cloud.macAddress() : 'Loading...' }}</code>
                                <button
                                    type="button"
                                    class="yqc-copy-btn"
                                    (click)="copyText(cloud.macAddress ? cloud.macAddress() : '', 'mac')"
                                    [title]="'YESTREAM.COPY_MAC' | translate"
                                >
                                    <mat-icon>{{ copiedField === 'mac' ? 'check' : 'content_copy' }}</mat-icon>
                                </button>
                            </div>
                        </div>

                        <div class="yqc-row">
                            <span class="yqc-label">{{ 'YESTREAM.DEVICE_KEY' | translate }}</span>
                            <div class="yqc-value-pill">
                                <code class="yqc-key">{{ cloud.deviceKey ? cloud.deviceKey() : '...' }}</code>
                                <button
                                    type="button"
                                    class="yqc-copy-btn"
                                    (click)="copyText(cloud.deviceKey ? cloud.deviceKey() : '', 'key')"
                                    [title]="'YESTREAM.COPY_KEY' | translate"
                                >
                                    <mat-icon>{{ copiedField === 'key' ? 'check' : 'content_copy' }}</mat-icon>
                                </button>
                            </div>
                        </div>

                        <div class="yqc-row">
                            <span class="yqc-label">{{ 'YESTREAM.WEB_PORTAL' | translate }}</span>
                            <div class="yqc-value-pill">
                                <a [href]="cloud.portalLoginUrl ? cloud.portalLoginUrl() : 'https://yestream.ai.studio'" target="_blank" rel="noopener noreferrer" class="yqc-link">
                                    <span>yestream.ai.studio</span>
                                    <mat-icon>open_in_new</mat-icon>
                                </a>
                            </div>
                        </div>

                        <div class="yqc-actions">
                            <button
                                mat-flat-button
                                color="primary"
                                type="button"
                                class="yqc-reload-btn"
                                [disabled]="cloud.syncLoading && cloud.syncLoading()"
                                (click)="reloadPlaylists()"
                            >
                                <mat-icon [class.spinning]="cloud.syncLoading && cloud.syncLoading()">sync</mat-icon>
                                {{ (cloud.syncLoading && cloud.syncLoading() ? 'YESTREAM.CHECKING_CLOUD' : 'YESTREAM.RELOAD_FROM_CLOUD') | translate }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        }
    `,
    styles: [`
        .yqc-card {
            background: var(--app-widget-bg);
            border: 1px solid var(--app-widget-border);
            border-radius: 14px;
            padding: 16px 20px;
            margin-bottom: 24px;
            color: var(--app-on-surface);
        }
        .yqc-header {
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 14px;
            padding-bottom: 10px;
            border-bottom: 1px solid var(--app-separator);
        }
        .yqc-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.82rem;
            font-weight: 600;
            text-transform: none;
            letter-spacing: 0.05em;
            color: var(--app-selection-text-color);
            mat-icon {
                font-size: 16px;
                width: 16px;
                height: 16px;
            }
        }
        .yqc-body {
            display: grid;
            gap: 20px;
            grid-template-columns: minmax(0, 1fr);
        }
        .yqc-qr-wrap {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            qrcode {
                border-radius: 8px;
                overflow: hidden;
                display: flex;
            }
        }
        .yqc-qr-placeholder {
            width: min(224px, 100%);
            aspect-ratio: 1;
            background: var(--app-content-bg);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            mat-icon {
                font-size: 48px;
                width: 48px;
                height: 48px;
                color: var(--app-muted-color);
            }
        }
        .yqc-qr-caption {
            font-size: 0.72rem;
            color: var(--app-muted-color);
            text-align: center;
        }
        .yqc-details {
            min-width: 0;
            padding-top: 16px;
            border-top: 1px solid var(--app-separator);
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .yqc-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 6px 12px;
            flex-wrap: wrap;
        }
        .yqc-label {
            font-size: 0.8rem;
            color: var(--app-muted-color);
            font-weight: 500;
        }
        .yqc-value-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: transparent;
            border: 1px solid var(--app-separator);
            padding: 3px 8px;
            border-radius: 6px;
            code {
                font-family: monospace;
                font-size: 0.85rem;
                font-weight: 600;
                color: var(--app-heading-color);
                letter-spacing: 0.04em;
            }
            .yqc-key {
                color: var(--app-selection-text-color);
                font-size: 0.95rem;
                letter-spacing: 0.08em;
            }
        }
        .yqc-copy-btn {
            background: transparent;
            border: none;
            color: var(--app-muted-color);
            cursor: pointer;
            padding: 0;
            display: flex;
            align-items: center;
            &:hover {
                color: var(--app-heading-color);
            }
            mat-icon {
                font-size: 14px;
                width: 14px;
                height: 14px;
            }
        }
        .yqc-link {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            color: var(--app-selection-text-color);
            text-decoration: none;
            font-size: 0.84rem;
            font-weight: 500;
            mat-icon {
                font-size: 13px;
                width: 13px;
                height: 13px;
            }
            &:hover {
                text-decoration: underline;
                color: var(--app-selection-text-color);
            }
        }
        .yqc-actions {
            margin-top: 6px;
            display: grid;
        }
        .yqc-reload-btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            font-size: 0.82rem;
            font-weight: 600;
            padding: 0 16px;
            height: 36px;
            border-radius: 8px;

            mat-icon {
                font-size: 18px;
                width: 18px;
                height: 18px;
            }
            .spinning {
                animation: spin 1s linear infinite;
            }
        }
        @media (max-width: 600px), (max-height: 540px) {
            .yqc-card {
                container-type: inline-size;
                padding: 10px 14px;
                margin-bottom: 8px;
            }
            .yqc-header { margin-bottom: 8px; padding-bottom: 6px; }
            .yqc-body { gap: 10px; }
            .yqc-qr-wrap { --qr-size: clamp(104px, 32vh, 148px); }
            .yqc-qr-wrap qrcode,
            .yqc-qr-placeholder {
                width: var(--qr-size);
                height: var(--qr-size);
            }
            .yqc-details { padding-top: 8px; gap: 6px; }
            .yqc-actions { margin-top: 0; }
            @container (min-width: 420px) {
                .yqc-body {
                    grid-template-columns: minmax(128px, 1fr) minmax(230px, 1.5fr);
                    align-items: center;
                }
                .yqc-details { border-top: 0; padding-top: 0; }
            }
        }
        @keyframes spin {
            100% { transform: rotate(360deg); }
        }
    `],
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class YestreamQuickConnectComponent {
    readonly cloud = inject(YESTREAM_CLOUD_BRIDGE, { optional: true }) as any;
    copiedField: string | null = null;

    async copyText(text: string, field = 'mac'): Promise<void> {
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

    reloadPlaylists(): void {
        if (this.cloud && typeof this.cloud.syncFromCloud === 'function') {
            void this.cloud.syncFromCloud();
        }
    }
}
