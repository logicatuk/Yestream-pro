import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
    cpSync,
    existsSync,
    mkdirSync,
    mkdtempSync,
    readFileSync,
    readdirSync,
    rmSync,
    writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { stageVegaPackage, verifyVegaPackage } from './vega-package.mjs';

function fixture(t) {
    const root = mkdtempSync(join(tmpdir(), 'tv-vega-package-'));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const build = join(root, 'dist/apps/tv');
    mkdirSync(join(build, 'assets'), { recursive: true });
    mkdirSync(join(root, 'apps/tv/vega'), { recursive: true });
    cpSync(
        new URL('./vega/manifest.toml', import.meta.url),
        join(root, 'apps/tv/vega/manifest.toml')
    );
    writeFileSync(
        join(build, 'appinfo.json'),
        JSON.stringify({
            version: '0.1.25',
            main: 'index.html',
            disableBackHistoryAPI: true,
        })
    );
    writeFileSync(
        join(build, 'index.html'),
        '<html><head><script defer src="./assets/tv.js"></script></head><body></body></html>'
    );
    writeFileSync(
        join(build, 'assets/tv.js'),
        '(function () { const compatible = 1; })();'
    );
    writeFileSync(join(build, 'icon.png'), 'synthetic icon');
    writeFileSync(join(build, 'large-icon.png'), 'synthetic LG icon');
    return { root, build };
}

test('Vega staging reuses the verified bundle/version/icon and leaves LG files byte-identical', (t) => {
    const { root, build } = fixture(t);
    const before = readdirSync(build)
        .filter((name) => name !== 'assets')
        .map((name) => [name, readFileSync(join(build, name))]);
    const input = stageVegaPackage(root);
    assert.equal(
        verifyVegaPackage(input),
        readFileSync(join(build, 'assets/tv.js')).length
    );
    assert.deepEqual(
        readFileSync(join(input, 'assets/tv.js')),
        readFileSync(join(build, 'assets/tv.js'))
    );
    assert.deepEqual(
        readFileSync(join(input, 'icon.png')),
        readFileSync(join(build, 'icon.png'))
    );
    assert.match(
        readFileSync(join(input, 'manifest.toml'), 'utf8'),
        /version = "0\.1\.25"/
    );
    assert.equal(existsSync(join(input, 'large-icon.png')), false);
    assert.equal(existsSync(join(input, 'appinfo.json')), false);
    assert.equal(existsSync(join(build, 'manifest.toml')), false);
    for (const [name, bytes] of before)
        assert.deepEqual(readFileSync(join(build, name)), bytes);
});
