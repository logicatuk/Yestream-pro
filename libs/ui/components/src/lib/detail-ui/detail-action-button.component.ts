import {
    ChangeDetectionStrategy,
    Component,
    ElementRef,
    DestroyRef,
    afterRenderEffect,
    inject,
    input,
    output,
} from '@angular/core';
import { MatIcon } from '@angular/material/icon';

/** External-player launch feedback carried by the primary button. */
export type DetailActionButtonState = 'idle' | 'launching' | 'stop';

/**
 * A text action of the details row. `primary` is the light call to action:
 * play icon plus a two-line label ("Continue" / "S02E03 · 18m left"), the
 * same surface as the dashboard hero's primary (`light-primary-button`
 * mixin). `secondary` is the ghost text button beside it ("Trailer").
 */
@Component({
    selector: 'app-detail-action-button',
    imports: [MatIcon],
    templateUrl: './detail-action-button.component.html',
    styleUrl: './detail-action-button.component.scss',
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DetailActionButtonComponent {
    readonly variant = input<'primary' | 'secondary'>('primary');
    readonly label = input.required<string>();
    /** Second, smaller line: episode code, time left, duration. */
    readonly meta = input<string | null>(null);
    readonly icon = input('play_arrow');
    readonly state = input<DetailActionButtonState>('idle');
    readonly disabled = input(false);
    readonly testId = input<string | null>(null);

    readonly focusOnEntry = input(false);
    private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);
    private readonly entryFocus =
        this.host.nativeElement.ownerDocument.activeElement;

    constructor() {
        let handled = false;
        const host = this.host.nativeElement;
        inject(DestroyRef).onDestroy(() => {
            if (
                this.focusOnEntry() &&
                host.contains(host.ownerDocument.activeElement) &&
                this.entryFocus instanceof HTMLElement &&
                this.entryFocus.isConnected
            ) {
                this.entryFocus.focus({ preventScroll: true });
            }
        });
        afterRenderEffect(() => {
            if (!this.focusOnEntry() || handled || this.disabled()) return;
            handled = true;
            if (host.closest('[inert]')) return;
            const doc = host.ownerDocument;
            if (
                doc.activeElement === doc.body ||
                doc.activeElement === host.closest('app-portal-detail-shell') ||
                doc.activeElement === this.entryFocus
            ) {
                host.querySelector('button')?.focus();
            }
        });
    }

    readonly pressed = output<void>();
}
