import {
    cpSync,
    existsSync,
    readFileSync,
    rmSync,
    writeFileSync,
} from 'node:fs';
import { strict as assert } from 'node:assert';
import { resolve } from 'node:path';
import { verifyTvBundle } from './build-check.mjs';

export const vegaInput = 'dist/tv-vega-input';

export function stageVegaPackage(workspace) {
    const build = resolve(workspace, 'dist/apps/tv');
    const input = resolve(workspace, vegaInput);
    const app = JSON.parse(readFileSync(build + '/appinfo.json', 'utf8'));

    // Clear previous staging directory
    rmSync(input, { recursive: true, force: true });
    cpSync(build, input, {
        recursive: true,
        filter: (file) =>
            !['appinfo.json', 'large-icon.png', 'config.xml'].includes(
                file.split(/[\\/]/).pop()
            ),
    });

    const template = readFileSync(
        resolve(workspace, 'apps/tv/vega/manifest.toml'),
        'utf8'
    );
    writeFileSync(
        input + '/manifest.toml',
        template.replace('__TV_VERSION__', app.version)
    );

    verifyVegaPackage(input);
    return input;
}

export function verifyVegaPackage(input) {
    const bytes = verifyTvBundle(input);
    assert.equal(
        existsSync(input + '/appinfo.json'),
        false,
        'Vega input must exclude LG metadata'
    );
    assert.equal(
        existsSync(input + '/config.xml'),
        false,
        'Vega input must exclude Tizen metadata'
    );
    assert.ok(
        existsSync(input + '/manifest.toml'),
        'Vega input must include manifest.toml'
    );
    const manifest = readFileSync(input + '/manifest.toml', 'utf8');
    assert.match(manifest, /schema-version\s*=\s*1/);
    assert.match(manifest, /id\s*=\s*"com\.yestream\.tv"/);
    assert.match(manifest, /categories\s*=\s*\[.*"com\.amazon\.category\.main".*\]/);
    assert.ok(
        existsSync(input + '/icon.png'),
        'Vega input must include the shared icon'
    );
    return bytes;
}
