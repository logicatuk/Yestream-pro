import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { stageVegaPackage } from './vega-package.mjs';

const workspace = process.cwd();
const input = stageVegaPackage(workspace);
const appinfo = JSON.parse(readFileSync('apps/tv/public/appinfo.json', 'utf8'));
const version = appinfo.version || '0.1.25';
const outputDir = join(workspace, 'dist/tv-vega-package');
mkdirSync(outputDir, { recursive: true });
const vpkgName = `yestream-tv-vega-${version}.vpkg`;
const vpkgPath = join(outputDir, vpkgName);

// Package using vega CLI if present, or zip container
const vegaCli = spawnSync('which', ['vega']).status === 0;
if (vegaCli) {
    const res = spawnSync('vega', ['package', '--input', input, '--output', vpkgPath], { stdio: 'inherit' });
    if (res.status !== 0) process.exit(res.status ?? 1);
} else {
    // .vpkg is the standard container bundle format
    const res = spawnSync('zip', ['-r', '-q', vpkgPath, '.'], { cwd: input, stdio: 'inherit' });
    if (res.status !== 0) process.exit(res.status ?? 1);
}

console.log(`Successfully built Amazon Vega OS package: ${vpkgPath}`);
