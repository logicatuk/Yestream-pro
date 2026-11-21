import type { Page } from '@playwright/test';
import { xtream } from './helpers';

/** Route TMDB traffic to the local fictional API and artwork. */
export async function enableMarketingTmdb(page: Page): Promise<void> {
    for (const origin of [
        'https://api.themoviedb.org/3/**',
        'https://image.tmdb.org/**',
    ]) {
        await page.route(origin, async (route) => {
            const url = new URL(route.request().url());
            const response = await route.fetch({
                url: `${xtream}/tmdb${url.pathname}${url.search}`,
            });
            await route.fulfill({ response });
        });
    }
}
