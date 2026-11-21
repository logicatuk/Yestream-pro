import type { Page } from '@playwright/test';
import { expect } from './fixtures';

/** Deterministic fictional metadata; never contacts a real metadata service. */
export async function interceptAgeRatingTmdb(page: Page) {
    let requests = 0;
    let classificationRequests = 0;
    let searchYear = '2020';
    const mediaTypes: string[] = [];
    await page.route('https://api.themoviedb.org/**', async (route) => {
        requests++;
        const url = new URL(route.request().url());
        const json = (body: unknown) => route.fulfill({ json: body });
        if (url.pathname.includes('/search/')) {
            classificationRequests++;
            const title =
                url.searchParams.get('query') || 'Classification Fixture';
            const year =
                url.searchParams.get('year') ||
                url.searchParams.get('first_air_date_year') ||
                searchYear;
            return json({
                results: [
                    {
                        id: 904201,
                        title,
                        original_title: title,
                        name: title,
                        original_name: title,
                        release_date: `${year}-01-01`,
                        first_air_date: `${year}-01-01`,
                        vote_count: 100,
                    },
                ],
            });
        }
        const match = url.pathname.match(/\/(movie|tv)\/(\d+)$/);
        if (match) {
            classificationRequests++;
            const mediaType = match[1];
            mediaTypes.push(mediaType);
            return json({
                id: Number(match[2]),
                title: 'Classification Fixture',
                name: 'Classification Fixture',
                overview:
                    'A fictional metadata fixture for classification checks.',
                original_language: 'en',
                credits: { cast: [], crew: [] },
                videos: { results: [] },
                ...(mediaType === 'movie'
                    ? {
                          release_dates: {
                              results: [
                                  {
                                      iso_3166_1: 'DE',
                                      release_dates: [
                                          { certification: '12', type: 4 },
                                      ],
                                  },
                                  {
                                      iso_3166_1: 'US',
                                      release_dates: [
                                          { certification: 'PG-13', type: 4 },
                                      ],
                                  },
                              ],
                          },
                      }
                    : {
                          content_ratings: {
                              results: [
                                  { iso_3166_1: 'DE', rating: '16' },
                                  { iso_3166_1: 'US', rating: 'TV-14' },
                              ],
                          },
                          aggregate_credits: { cast: [] },
                      }),
            });
        }
        return json({});
    });
    return {
        requests: () => requests,
        classificationRequests: () => classificationRequests,
        mediaTypes,
        setYear: (year: string) => {
            searchYear = year;
        },
    };
}

/**
 * Persist age-rating country without the removed Metadata settings UI.
 * Writes the ngx-pwa IndexedDB settings record, then reloads.
 */
export async function setAgeRatingCountry(
    page: Page,
    country: string,
    _enableTmdb = false
) {
    if (page.url() === 'about:blank') {
        await page.goto('/');
    }
    await page.evaluate(async (nextCountry) => {
        await new Promise<void>((resolve, reject) => {
            const open = indexedDB.open('ngStorage');
            open.onerror = () => reject(open.error ?? new Error('idb open'));
            open.onsuccess = () => {
                const db = open.result;
                const storeName = db.objectStoreNames.contains('localStorage')
                    ? 'localStorage'
                    : db.objectStoreNames[0];
                const tx = db.transaction(storeName, 'readwrite');
                const store = tx.objectStore(storeName);
                const read = store.get('settings');
                read.onerror = () => reject(read.error ?? new Error('idb get'));
                read.onsuccess = () => {
                    const current =
                        read.result && typeof read.result === 'object'
                            ? (read.result as Record<string, unknown>)
                            : {};
                    const previousTmdb =
                        current['tmdb'] && typeof current['tmdb'] === 'object'
                            ? (current['tmdb'] as Record<string, unknown>)
                            : {};
                    store.put(
                        {
                            ...current,
                            ageRatingCountry: nextCountry,
                            tmdb: {
                                ...previousTmdb,
                                enabled: true,
                                apiKey:
                                    typeof previousTmdb['apiKey'] === 'string'
                                        ? previousTmdb['apiKey']
                                        : '',
                            },
                        },
                        'settings'
                    );
                };
                tx.oncomplete = () => {
                    db.close();
                    resolve();
                };
                tx.onerror = () => reject(tx.error ?? new Error('idb tx'));
            };
        });
    }, country);
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
}

export function ageRating(page: Page) {
    return page.locator(
        'app-age-rating-chip:visible [data-test-id="age-rating-chip"]'
    );
}

/** Use the saved theme so body tokens and the hero's own scrim agree. */
export async function setAgeRatingTheme(
    page: Page,
    theme: 'Light' | 'Dark',
    detailUrl: string
) {
    await page.getByRole('link', { name: 'Open settings' }).click();
    await page.locator('[data-test-id="settings-section-appearance"]').click();
    await page
        .locator('[data-test-id="select-theme"]')
        .getByRole('radio', { name: theme, exact: true })
        .click();
    const save = page.locator('[data-test-id="save-settings"]');
    await save.click();
    await expect(save).toBeHidden();
    await page.locator('[data-test-id="workspace-header-back"]').click();
    await expect(page).toHaveURL(detailUrl);
    await expect(page.locator('mat-snack-bar-container')).toHaveCount(0);
}
