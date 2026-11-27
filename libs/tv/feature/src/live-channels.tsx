import { tr } from '@iptvnator/tv/ui';
import { useRef } from 'preact/hooks';
import {
    ChannelLogo,
    Empty,
    restoreFocus,
    VirtualCollection,
} from '@iptvnator/tv/ui';
import type { TvModel } from './use-tv';
import { categoryKey, useLiveBrowse } from './use-live-browse';
export function LiveChannels({
    tv,
    browse,
    overlay = false,
    pane,
}: {
    tv: TvModel;
    overlay?: boolean;
    pane?: 'categories' | 'channels';
    browse: ReturnType<typeof useLiveBrowse>;
}) {
    const categories = pane ? pane === 'categories' : browse.categoriesOpen;
    const lastClickRef = useRef<{ id: string; time: number }>({
        id: '',
        time: 0,
    });
    const pinned =
        tv.playing &&
        tv.route.category === tv.playingCategory &&
        !tv.catalog.items.some((item) => item.id === tv.playing?.id)
            ? tv.playing
            : undefined;
    const items = pinned ? [pinned, ...tv.catalog.items] : tv.catalog.items;
    return (
        <section
            class={`channel-pane ${categories ? 'category-pane' : 'station-pane'}`}
            aria-label={
                categories ? 'Channel categories' : 'Channels'
            }
        >
            <div class="channel-pane-header">
                {categories ? (
                    <h2>{tr("Categories")}</h2>
                ) : (
                    <button
                        data-focus="live-categories"
                        onClick={browse.back}
                        aria-label="Back to categories"
                    >
                        <span aria-hidden="true">← </span>
                        {browse.categoryName}
                    </button>
                )}
                <span class="muted">
                    {categories
                        ? 'Choose a category'
                        : overlay
                          ? 'OK: switch channel · Back: close'
                          : 'OK: preview · OK again: fullscreen'}
                </span>
            </div>
            <div
                class="channels"
                key={categories ? 'categories' : tv.catalogKey}
            >
                {categories ? (
                    <VirtualCollection
                        layout="channels"
                        items={browse.categories}
                        restoreKey={categoryKey(tv.route.category)}
                        restoreScroll={browse.categoryScroll}
                        render={(category) => (
                            <button
                                class="live-category"
                                data-focus={category.id}
                                aria-pressed={
                                    category.categoryId === tv.route.category
                                }
                                onClick={() =>
                                    browse.choose(category.categoryId)
                                }
                            >
                                <strong>{category.categoryId ? category.name : tr('All channels')}</strong>
                                <span aria-hidden="true">→</span>
                            </button>
                        )}
                    />
                ) : (
                    <VirtualCollection
                        layout="channels"
                        items={items}
                        more={tv.hasMore}
                        busy={tv.catalogBusy}
                        error={tv.catalogError}
                        loadMore={tv.loadMore}
                        restoreKey={browse.channelKey}
                        restoreScroll={browse.channelScroll}
                        render={(item, n) => (
                            <button
                                class={`channel ${tv.playing?.id === item.id && tv.player.current?.hasConfirmedPlayback ? 'is-playing' : ''}`}
                                data-focus={item.id}
                                aria-pressed={tv.selected?.id === item.id}
                                onFocus={() => tv.setSelected(item)}
                                onBlur={() => {
                                    lastClickRef.current.id = '';
                                }}
                                onKeyDown={(event) => {
                                    if (event.key === 'Enter' && event.repeat)
                                        event.preventDefault();
                                }}
                                onClick={() => {
                                    const now = Date.now();
                                    const secondPress =
                                        lastClickRef.current.id === item.id &&
                                        now - lastClickRef.current.time < 650;
                                    lastClickRef.current = {
                                        id: secondPress ? '' : item.id,
                                        time: now,
                                    };
                                    tv.setSelected(item);
                                    if (secondPress) {
                                        tv.setFullscreen(true);
                                        restoreFocus('player-toggle');
                                    } else {
                                        void tv.play(item);
                                    }
                                }}
                            >
                                <span class="channel-number">
                                    {item === pinned
                                        ? '●'
                                        : String(
                                              n + 1 - (pinned ? 1 : 0)
                                          ).padStart(2, '0')}
                                </span>
                                <ChannelLogo src={item.poster} />
                                <span>
                                    <strong>{item.title}</strong>
                                    <small>
                                        {tv.playing?.id === item.id
                                            ? tv.player.current
                                                  ?.hasConfirmedPlayback
                                                ? '● Playing'
                                                : 'Starting / paused'
                                            : (tv.data.sources.find(
                                                  (source) =>
                                                      source.id ===
                                                      item.sourceId
                                              )?.name ?? 'Source unavailable')}
                                    </small>
                                </span>
                            </button>
                        )}
                    />
                )}
                {!categories &&
                !tv.busy &&
                !tv.catalogError &&
                !items.length ? (
                    <Empty>{tr("No channels in this category.")}</Empty>
                ) : null}
                {categories && tv.catalogError ? (
                    <div role="alert" class="load-more-status">
                        {tv.catalogError}{' '}
                        <button onClick={tv.loadMore}>{tr("Retry loading")}</button>
                    </div>
                ) : null}
            </div>
        </section>
    );
}
