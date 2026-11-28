import { useState } from 'preact/hooks';
import { TvDialog, tr } from '@iptvnator/tv/ui';
import type { TvModel } from './use-tv';

export function CatalogSearch({ tv }: { tv: TvModel }) {
    const r = tv.route;
    const [originalQuery, setOriginalQuery] = useState<string | null>(null);
    const list = tv.catalog.items;
    function cancelSearch() {
        tv.setRoute({ ...r, query: originalQuery ?? '', page: 0 });
        setOriginalQuery(null);
    }
    return (
        <>
            <div class="catalog-search-control">
                <span>{tr('Search this source')}</span>
                <button data-focus="catalog-search" onClick={() => setOriginalQuery(r.query)}>
                    {r.query || tr('Search')}
                </button>
            </div>
            {originalQuery !== null && (
                <TvDialog title={tr('Search this source')} close={cancelSearch} className="catalog-search-dialog">
                    <form onSubmit={event => { event.preventDefault(); setOriginalQuery(null); }}>
                        <input type="search" data-ime-active data-dialog-initial aria-label={tr('Search this source')}
                            value={r.query} onInput={event => tv.setRoute({ ...r, page: 0, query: event.currentTarget.value })} />
                        <button type="submit">{tr('Done')}</button>
                    </form>
                    <div role="status">{tv.catalogBusy ? tr('Searching…') : tv.catalogError || String(tv.catalog.total)}</div>
                    {r.query && <ul>{list.slice(0, 3).map(item => <li key={item.id}>{item.title}</li>)}</ul>}
                </TvDialog>
            )}
        </>
    );
}
