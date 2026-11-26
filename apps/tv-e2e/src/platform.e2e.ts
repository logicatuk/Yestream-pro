import { expect, test } from '@playwright/test';
import { tvBackCodes } from '@iptvnator/tv/util';
import { addSource, nav, start } from './helpers';
import { playLive } from './live-media';

test('Samsung remote OK activates Movies and Playlists once per press', async ({ page }) => {
    await page.addInitScript(() => Object.assign(window, { tizen: {} }));
    await start(page);
    const nav = page.getByRole('navigation', { name: 'Main navigation' });
    for (const name of ['Movies', 'Playlists']) {
        const button = nav.getByRole('button', { name, exact: true });
        await button.focus();
        await button.evaluate((el: HTMLElement) => {
            el.addEventListener('click', () => {
                el.dataset.activations = String(Number(el.dataset.activations || 0) + 1);
            });
        });
        if (name === 'Movies') {
            await button.dispatchEvent('keydown', { key: 'Unidentified', keyCode: 13 });
            await button.dispatchEvent('keydown', { key: 'Unidentified', keyCode: 13, repeat: true });
        } else {
            await page.keyboard.press('Enter');
        }
        await expect(button).toHaveAttribute('aria-current', 'page');
        await expect(button).toHaveAttribute('data-activations', '1');
    }
});

for (const platform of ['webos', 'tizen'] as const) {
    test(
        platform +
            ' Back closes pickers, returns from Settings and exits only at Home',
        async ({ page }) => {
            await page.addInitScript((platform) => {
                const evidence = { exits: 0, keys: [] as string[] };
                Object.assign(window, { remoteEvidence: evidence });
                if (platform === 'tizen')
                    Object.assign(window, {
                        tizen: {
                            tvinputdevice: {
                                registerKey: (name: string) =>
                                    evidence.keys.push(name),
                            },
                            application: {
                                getCurrentApplication: () => ({
                                    appInfo: { id: 'SyntheticT.TV' },
                                    exit: () => evidence.exits++,
                                }),
                            },
                        },
                    });
                else
                    Object.assign(window, {
                        webOS: { platformBack: () => evidence.exits++ },
                    });
            }, platform);
            await start(page);
            await nav(page, 'Settings');
            const category = page.getByRole('tab', {
                name: 'Appearance',
                exact: false,
            });
            await category.click();
            await page.keyboard.press('ArrowRight');
            const picker = page.getByRole('combobox', {
                name: 'Home composition',
                exact: true,
            });
            await page.keyboard.press('Enter');
            const dialog = page.getByRole('dialog', {
                name: 'Home composition',
                exact: true,
            });
            await expect(dialog).toBeVisible();
            await dialog.dispatchEvent('keydown', {
                key: 'Unidentified',
                keyCode: tvBackCodes[platform],
            });
            await expect(dialog).toBeHidden();
            await expect(picker).toBeFocused();
            await picker.dispatchEvent('keydown', {
                key: 'Unidentified',
                keyCode: tvBackCodes[platform],
            });
            await expect(category).toBeFocused();
            if (platform === 'tizen') {
                await page
                    .getByRole('tab', { name: 'About', exact: false })
                    .click();
                await expect(page.getByRole('tabpanel')).toContainText(
                    'Samsung Tizen TV'
                );
                await expect(page.getByRole('tabpanel')).toContainText(
                    'SyntheticT.TV'
                );
            }
            const evidence = () =>
                page.evaluate(
                    () =>
                        (
                            window as unknown as {
                                remoteEvidence: {
                                    exits: number;
                                    keys: string[];
                                };
                            }
                        ).remoteEvidence
                );
            expect((await evidence()).exits).toBe(0);
            await nav(page, 'Home');
            await page.locator('body').dispatchEvent('keydown', {
                key: 'Unidentified',
                keyCode: tvBackCodes[platform],
            });
            expect((await evidence()).exits).toBe(1);
            expect((await evidence()).keys).toEqual(
                platform === 'tizen'
                    ? [
                          'MediaPlay',
                          'MediaPause',
                          'MediaStop',
                          'MediaRewind',
                          'MediaFastForward',
                          'MediaPlayPause',
                      ]
                    : []
            );
        }
    );
}

test('Samsung screensaver is disabled only while the native player is playing', async ({
    page,
}) => {
    await page.addInitScript(() => {
        const states: number[] = [];
        Object.assign(window, {
            screenSaverStates: states,
            webapis: {
                appcommon: {
                    AppCommonScreenSaverState: {
                        SCREEN_SAVER_ON: 1,
                        SCREEN_SAVER_OFF: 0,
                    },
                    setScreenSaver: (state: number) => states.push(state),
                },
            },
        });
    });
    const state = () =>
        page.evaluate(() => {
            const evidence = window as unknown as {
                screenSaverStates: number[];
            };
            return evidence.screenSaverStates.at(-1);
        });
    await start(page);
    await expect.poll(state).toBe(1);
    await addSource(page, 'xtream');
    await playLive(page);
    await expect.poll(state).toBe(0);
    await page.getByRole('button', { name: /^Pause/ }).click();
    await expect.poll(state).toBe(1);
    await page.getByRole('button', { name: /^Play ▶/ }).click();
    await expect.poll(state).toBe(0);
    await page.locator('body').dispatchEvent('keydown', {
        key: 'MediaStop',
        keyCode: 413,
    });
    await expect(page.locator('video[src],video source')).toHaveCount(0);
    await expect.poll(state).toBe(1);
});
