import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveStalkerArtwork } from '@iptvnator/portal/stalker/client';
import {
    applySettingsDraft,
    initialData,
    parseSettingsDraft,
    phoneSettingsDefaults,
} from '@iptvnator/tv/util';
test('Stalker artwork resolves root paths and falls through blank or unsupported fields', () => {
    const base = 'https://portal.example/stalker_portal/server/load.php';
    assert.equal(
        resolveStalkerArtwork(base, '', '/stalker_portal/screenshots/1.jpg'),
        'https://portal.example/stalker_portal/screenshots/1.jpg'
    );
    assert.equal(
        resolveStalkerArtwork(base, 'N/A', 'assets/poster.jpg'),
        'https://portal.example/assets/poster.jpg'
    );
    assert.equal(
        resolveStalkerArtwork(base, '//cdn.example/a.jpg'),
        'https://cdn.example/a.jpg'
    );
    assert.equal(
        resolveStalkerArtwork(
            base,
            'javascript:alert(1)',
            'data:image/png;base64,AA',
            'https://user:pass@host/a'
        ),
        undefined
    );
    assert.equal(
        resolveStalkerArtwork(base, 'https://cdn.example/a.jpg?size=300'),
        'https://cdn.example/a.jpg?size=300'
    );
});
test('phone settings leave TMDB always-on and preserve unrelated TV data', () => {
    const data = initialData();
    data.tmdb.apiKey = 'existing-secret';
    const defaults = phoneSettingsDefaults(data);
    assert.equal(JSON.stringify(defaults).includes('existing-secret'), false);
    assert.equal('tmdb' in defaults, false);
    const next = applySettingsDraft(data, {
        ...defaults,
        layout: 'shelf',
    });
    assert.equal(next.tmdb.apiKey, 'existing-secret');
    assert.equal(next.tmdb.enabled, true);
    assert.equal(next.layout, 'shelf');
    assert.equal(next.sources, data.sources);
    assert.equal(next.positions, data.positions);
});
test('phone settings reject malformed values and ignore attacker-controlled fields', () => {
    const value = {
        layout: 'cinema',
        epg: true,
    };
    assert.throws(() => parseSettingsDraft({ ...value, epg: 'true' }));
    const next = applySettingsDraft(initialData(), {
        ...value,
        backend: 'https://attacker.invalid',
    } as never);
    assert.equal(next.backend, '');
    assert.equal(next.tmdb.enabled, true);
});
test('phone settings carry the playback switches and keep the TV values when absent', () => {
    const data = initialData();
    data.seriesAutoplay = false;
    const defaults = phoneSettingsDefaults(data);
    assert.equal(defaults.seriesAutoplay, false);
    assert.equal(defaults.playerUpNextCard, true);
    const value = {
        layout: 'cinema',
        epg: true,
    };
    const kept = applySettingsDraft(data, value);
    assert.equal(kept.seriesAutoplay, false);
    assert.equal(kept.playerUpNextCard, true);
    const changed = applySettingsDraft(data, {
        ...value,
        seriesAutoplay: true,
        playerUpNextCard: false,
    });
    assert.equal(changed.seriesAutoplay, true);
    assert.equal(changed.playerUpNextCard, false);
    assert.throws(() =>
        parseSettingsDraft({ ...value, playerUpNextCard: 'false' })
    );
    assert.equal('seriesAutoplay' in parseSettingsDraft(value), false);
});
