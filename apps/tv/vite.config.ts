import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';
import { resolve } from 'node:path';
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tvBuildInfo } from './build-info';

const require = createRequire(import.meta.url);
const workspace = process.cwd();
const paths = JSON.parse(readFileSync('tsconfig.base.json', 'utf8'))
    .compilerOptions.paths as Record<string, string[]>;

function getUnicodeRanges() {
    const pnpmDir = resolve(workspace, 'node_modules/.pnpm');
    const entry = readdirSync(pnpmDir).find((e) => e.startsWith('regexpu-core@'));
    if (!entry) throw new Error('Could not find regexpu-core in pnpm node_modules');
    const regexpuPath = resolve(pnpmDir, entry, 'node_modules/regexpu-core');
    const rewritePattern = require(regexpuPath);
    return {
        pL_range: rewritePattern('\\p{L}', 'u', { unicodePropertyEscapes: 'transform' }).slice(1, -1),
        pLl_range: rewritePattern('\\p{Ll}', 'u', { unicodePropertyEscapes: 'transform' }).slice(1, -1),
        pN_range: rewritePattern('\\p{N}', 'u', { unicodePropertyEscapes: 'transform' }).slice(1, -1),
        pM_range: rewritePattern('\\p{M}', 'u', { unicodePropertyEscapes: 'transform' }).slice(1, -1),
    };
}

let unicodeRanges: ReturnType<typeof getUnicodeRanges> | null = null;
function transpileUnicodeRegex(src: string): string {
    if (!unicodeRanges) unicodeRanges = getUnicodeRanges();
    const { pL_range, pLl_range, pN_range, pM_range } = unicodeRanges;
    return src
        .replace(/\[\^\\\\p\{L\}\\\\p\{N\}\\\\p\{M\}\]\+/g, `[^${pL_range}${pN_range}${pM_range}]+`)
        .replace(/\[\^\\\\p\{L\}\\\\p\{N\}\]\+/g, `[^${pL_range}${pN_range}]+`)
        .replace(/\[\^\\\\p\{L\}\\\\d\]/g, `[^${pL_range}\\d]`)
        .replace(/\[\^\\\\p\{L\}\]/g, `[^${pL_range}]`)
        .replace(/\(\?!\\\\p\{L\}\)/g, `(?![${pL_range}])`)
        .replace(/\\\\p\{Ll\}/g, `[${pLl_range}]`)
        .replace(/\\\\p\{L\}/g, `[${pL_range}]`);
}

export default defineConfig({
    root: resolve(workspace, 'apps/tv'),
    base: './',
    define: { __TV_BUILD_INFO__: JSON.stringify(tvBuildInfo(workspace)) },
    plugins: [
        preact({ devToolsEnabled: false }),
        {
            name: 'tv-runtime-contract',
            apply: 'build',
            renderChunk(code) {
                const transformed = transpileUnicodeRegex(code);
                if (transformed.includes('\\p{')) {
                    this.error(
                        'TV bundle contains untranspiled unicode property escape: ' +
                            (transformed.match(/\\p\{[^}]+\}/g) || []).join(', ')
                    );
                }
                if (/\(\?<[!=]/.test(transformed)) {
                    this.error('TV bundle contains unsupported regex lookbehind');
                }
                return { code: transformed, map: null };
            },
            generateBundle() {
                for (const id of this.getModuleIds()) {
                    if (
                        /^(?:node:|electron$)/.test(id) ||
                        id.includes('__vite-browser-external')
                    )
                        this.error('TV output contains a non-browser module');
                    if (
                        /node_modules\/(?:@angular|@ngrx|electron|rxjs)\//.test(
                            id
                        )
                    )
                        this.error(
                            'TV output contains a forbidden runtime dependency'
                        );
                }
            },
            closeBundle() {
                const file = resolve(workspace, 'dist/apps/tv/index.html');
                // Packaged file:// pages need a classic script, not a CORS module fetch.
                writeFileSync(
                    file,
                    readFileSync(file, 'utf8')
                        .replace(/ type="module"/g, ' defer')
                        .replace(/ crossorigin/g, '')
                );
            },
        },
    ],
    resolve: {
        alias: Object.keys(paths)
            .filter((k) => k.startsWith('@iptvnator/'))
            // Vite matches the first prefix: a sub-entrypoint must precede
            // its parent barrel, regardless of tsconfig declaration order.
            .sort((a, b) => b.length - a.length)
            .map((find) => ({
                find,
                replacement: resolve(workspace, paths[find][0]),
            })),
    },
    server: { port: 4310, strictPort: true },
    build: {
        outDir: '../../dist/apps/tv',
        emptyOutDir: true,
        target: ['chrome53', 'es2015'],
        cssTarget: 'chrome53',
        modulePreload: false,
        rollupOptions: {
            output: { format: 'iife' },
        },
    },
});
