import {
    ChangeDetectionStrategy,
    Component,
} from '@angular/core';
import { XtreamStore } from '@iptvnator/portal/xtream/data-access';
import { SearchResultsComponent } from './xtream-search-results.lazy';

@Component({
    selector: 'app-global-search-results',
    imports: [
        SearchResultsComponent,
    ],
    providers: [XtreamStore],
    templateUrl: './global-search-route.component.html',
    styleUrl: './global-search-route.component.scss',
    changeDetection: ChangeDetectionStrategy.OnPush,
})
export class GlobalSearchRouteComponent {}
