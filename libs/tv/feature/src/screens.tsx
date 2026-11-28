import { CatalogSearch } from './catalog-search';
import { tr } from '@iptvnator/tv/ui';
import { RecentChannels } from './recent-channels';
import type { HomeFeature } from './use-home-feature';
import { storedMediaPoster } from '@iptvnator/tv/data-access';
import { CatalogOrder, CatalogSortNotice } from './catalog-order';
import {
    Empty,
    HorizontalRail,
    TvSelect,
    Hero,
    VirtualCollection,
    Poster,
} from '@iptvnator/tv/ui';
import { mediaTitle, Media } from '@iptvnator/tv/util';
import { TvModel } from './use-tv';
import { ViewingCard } from './viewing-card';
export function Home({
    tv,
    feature,
    actions,
    detailsBusy,
}: {
    tv: TvModel;
    feature: HomeFeature;
    actions: {
        open: (item: Media) => void;
        play: (item: Media) => void;
        leave: () => void;
    };
    detailsBusy: boolean;
}) {
    const sourceName = (item: Media) =>
        tv.data.sources.find((s) => s.id === item.sourceId)?.name ??
        'Source unavailable';
    const history = feature.history;
    const catalogSource =
        tv.data.sources.find((s) => s.id === tv.data.activeId)?.name ??
        'Selected source';
    const rails: [string, string, Media[]][] = [
        [
            'favorite-channels',
            tr('Favorite channels'),
            tv.data.favorites.filter((m) => m.kind === 'live').slice(0, 8),
        ],
        [
            'saved-movies',
            tr('Saved films'),
            tv.data.favorites
                .filter((m) => m.kind === 'movie')
                .slice(-12)
                .reverse(),
        ],
        [
            'saved-series',
            tr('Saved series'),
            tv.data.favorites
                .filter((m) => m.kind === 'series' || m.kind === 'episode')
                .slice(-12)
                .reverse(),
        ],
        [
            'catalog-movies',
            `Films · ${catalogSource}`,
            tv.home.filter((m) => m.kind === 'movie'),
        ],
        [
            'catalog-series',
            `Series · ${catalogSource}`,
            tv.home.filter((m) => m.kind === 'series'),
        ],
        [
            'catalog-live',
            `On television · ${catalogSource}`,
            tv.home.filter((m) => m.kind === 'live'),
        ],
    ];
    return (
        <>
            <Hero
                item={feature.item}
                progress={feature.progress}
                play={actions.play}
                index={feature.index}
                count={feature.count}
                select={feature.select}
                open={actions.open}
                sourceName={feature.item ? sourceName(feature.item) : undefined}
                detailsBusy={detailsBusy}
                compact={tv.data.layout === 'shelf'}
            />
            {history.length ? (
                <section>
                    <h2>{tr("Continue watching")}</h2>
                    <HorizontalRail label="Continue watching">
                        <div class="rail" data-tv-horizontal>
                            {history.map((p) => (
                                <ViewingCard
                                    key={p.item.id}
                                    tv={tv}
                                    progress={p}
                                    actions={actions}
                                />
                            ))}
                        </div>
                    </HorizontalRail>
                </section>
            ) : null}
            <RecentChannels data={tv.data} play={actions.play} />
            {rails
                .filter(([, , list]) => list.length)
                .map(([railId, title, list]) => (
                    <section key={railId}>
                        <h2>{title}</h2>
                        <HorizontalRail label={title}>
                            <div class="rail" data-tv-horizontal>
                                {list.map((item) => (
                                    <Poster
                                        key={item.id}
                                        focusKey={JSON.stringify([
                                            'home',
                                            railId,
                                            item.id,
                                        ])}
                                        item={{
                                            ...item,
                                            title: mediaTitle(item),
                                            poster: storedMediaPoster(
                                                item,
                                                tv.data.sources.find(
                                                    (s) =>
                                                        s.id === item.sourceId
                                                ),
                                                [
                                                    ...tv.home,
                                                    ...tv.data.favorites,
                                                ]
                                            ),
                                        }}
                                        open={() => actions.open(item)}
                                        sourceName={sourceName(item)}
                                    />
                                ))}
                            </div>
                        </HorizontalRail>
                    </section>
                ))}
            {!history.length &&
            !tv.data.favorites.length &&
            !tv.home.length &&
            !tv.busy ? (
                <Empty>
                    {tv.data.sources.length ? (
                        <>
                            <p>
                                Watch a title or save a favorite to see it here,
                                across all your sources.
                            </p>
                            <button
                                class="primary"
                                onClick={() => tv.navigate('movies')}
                            >{tr("Browse movies")}</button>
                        </>
                    ) : (
                        <>
                            <h2>Your screen, your sources.</h2>
                            <button
                                class="primary"
                                onClick={() => tv.navigate('sources')}
                            >
                                Add your first source
                            </button>
                        </>
                    )}
                </Empty>
            ) : null}
        </>
    );
}
export function CatalogScreen({ tv }: { tv: TvModel }) {
    const r = tv.route;
    const list = tv.catalog.items;
    const categoryList = r.view === 'movies' || r.view === 'series';
    return (
        <>
            {!categoryList && <div class="catalog-filters">
                <CatalogSearch tv={tv} />
                {r.view === 'search' ? (
                    <label>{tr("Content")}<TvSelect
                            label={tr("Content type")}
                            value={r.kind}
                            options={[
                                { value: 'movie', label: tr('Movies') },
                                { value: 'series', label: tr('Series') },
                                { value: 'live', label: 'Live TV' },
                            ]}
                            onChange={(value) =>
                                tv.setRoute({
                                    ...r,
                                    kind: value as typeof r.kind,
                                    page: 0,
                                    category: '',
                                })
                            }
                        />
                    </label>
                ) : null}
                {!categoryList && (<label>{tr("Category")}<TvSelect
                        label={tr("Category")}
                        value={r.category}
                        options={[
                            { value: '', label: tr('All categories') },
                            ...tv.catalog.categories.map((c) => ({
                                value: c.id,
                                label: c.name,
                            })),
                        ]}
                        onChange={(value) =>
                            tv.setRoute({ ...r, category: value, page: 0 })
                        }
                    />
                </label>) }
                {r.kind === 'movie' || r.kind === 'series' ? (
                    <CatalogOrder tv={tv} kind={r.kind} />
                ) : null}
            </div>}
            {!categoryList && <CatalogSortNotice tv={tv} />}
            <div class={categoryList ? 'catalog-browser' : undefined}>
            {categoryList && <section class="catalog-categories" aria-label={tr("Categories")}>
                <h2>{tr("Categories")}</h2>
                <div class="channels">
                    <VirtualCollection layout="channels"
                        items={[{ id: '', name: 'All categories' }, ...tv.catalog.categories]}
                        render={(category) => (
                            <button class="live-category" data-focus={`catalog-category:${category.id}`}
                                aria-pressed={r.category === category.id}
                                onClick={() => tv.setRoute({ ...r, category: category.id, page: 0 })}>
                                <strong>{category.id ? category.name : tr('All categories')}</strong>
                            </button>
                        )}
                    />
                </div>
            </section>}
            <div class={categoryList ? 'catalog-results' : 'search-results'}>
            <VirtualCollection
                key={tv.catalogKey}
                layout={r.kind === 'live' ? 'stations' : 'posters'}
                items={list}
                more={tv.hasMore}
                busy={tv.catalogBusy}
                error={tv.catalogError}
                loadMore={tv.loadMore}
                restoreKey={tv.restoreKey}
                restoreScroll={tv.restoreScroll}
                render={(item) => <Poster item={item} open={tv.open} />}
            />
            {!tv.busy && !tv.catalogBusy && !list.length ? (
                <Empty>{tr("No titles in this category. Try another category or search.")}</Empty>
            ) : null}
            </div></div>
        </>
    );
}
