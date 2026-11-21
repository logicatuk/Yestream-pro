import { execSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import sharp from 'sharp';

const workspace = resolve(process.cwd());

const TRANSPARENT_PNG = '/Users/ayyoubess/.gemini/antigravity/brain/4025eddd-a31a-4182-9952-886da9363413/.user_uploaded/media_1795303136556_fd0924e9.png';
const PURPLE_JPG = '/Users/ayyoubess/.gemini/antigravity/brain/4025eddd-a31a-4182-9952-886da9363413/.user_uploaded/media_1795303136575_c654d574.jpg';

function createIco(items) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // ICO format
  header.writeUInt16LE(items.length, 4);
  let offset = 6 + items.length * 16;
  const entries = [];
  for (const item of items) {
    const e = Buffer.alloc(16);
    e.writeUInt8(item.w >= 256 ? 0 : item.w, 0);
    e.writeUInt8(item.h >= 256 ? 0 : item.h, 1);
    e.writeUInt8(0, 2); // color count
    e.writeUInt8(0, 3); // reserved
    e.writeUInt16LE(1, 4); // color planes
    e.writeUInt16LE(32, 6); // bpp
    e.writeUInt32LE(item.data.length, 8); // size
    e.writeUInt32LE(offset, 12); // offset
    entries.push(e);
    offset += item.data.length;
  }
  return Buffer.concat([header, ...entries, ...items.map((x) => x.data)]);
}

async function main() {
  console.log('Generating branded icons for all platforms...');

  // 1. Create base masters
  // Rounded squircle (20% corner radius) for modern desktop & mobile app cards
  const roundedMask = Buffer.from(
    '<svg width="1024" height="1024"><rect x="0" y="0" width="1024" height="1024" rx="204" ry="204" fill="white"/></svg>'
  );
  const roundedMaster = await sharp(PURPLE_JPG)
    .composite([{ input: roundedMask, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // Circular mask for round Android launcher icons
  const circleMask = Buffer.from(
    '<svg width="1024" height="1024"><circle cx="512" cy="512" r="512" fill="white"/></svg>'
  );
  const circleMaster = await sharp(PURPLE_JPG)
    .composite([{ input: circleMask, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // Full-bleed square master
  const squareMaster = await sharp(PURPLE_JPG).png().toBuffer();

  // Transparent logo master
  const transparentMaster = await sharp(TRANSPARENT_PNG).png().toBuffer();

  // 2. apps/web/src/assets/icons/
  console.log('Generating apps/web/src/assets/icons/...');
  const webIconsDir = resolve(workspace, 'apps/web/src/assets/icons');
  mkdirSync(webIconsDir, { recursive: true });

  const iconSizes = [16, 32, 48, 64, 128, 192, 256, 512, 1024];
  for (const s of iconSizes) {
    await sharp(roundedMaster)
      .resize(s, s)
      .toFile(resolve(webIconsDir, `icon-${s}.png`));
  }

  // Primary icon.png (512x512)
  await sharp(roundedMaster)
    .resize(512, 512)
    .toFile(resolve(webIconsDir, 'icon.png'));

  // Transparent logo for in-app headers and server-sign-in
  await sharp(transparentMaster)
    .resize(256, 256)
    .toFile(resolve(webIconsDir, 'icon-tv-256.png'));

  // Android Chrome / PWA icons
  await sharp(roundedMaster)
    .resize(192, 192)
    .toFile(resolve(webIconsDir, 'android-chrome-192x192.png'));
  await sharp(roundedMaster)
    .resize(512, 512)
    .toFile(resolve(webIconsDir, 'android-chrome-512x512.png'));

  // Maskable icons (square bleed so OS mask cuts safely)
  await sharp(squareMaster)
    .resize(192, 192)
    .toFile(resolve(webIconsDir, 'android-chrome-maskable-192x192.png'));
  await sharp(squareMaster)
    .resize(512, 512)
    .toFile(resolve(webIconsDir, 'android-chrome-maskable-512x512.png'));

  // Apple touch icon
  await sharp(roundedMaster)
    .resize(180, 180)
    .toFile(resolve(webIconsDir, 'apple-touch-icon.png'));

  // Favicons
  await sharp(roundedMaster)
    .resize(64, 64)
    .toFile(resolve(webIconsDir, 'favicon.png'));
  await sharp(roundedMaster)
    .resize(256, 256)
    .toFile(resolve(webIconsDir, 'favicon.256x256.png'));
  await sharp(roundedMaster)
    .resize(512, 512)
    .toFile(resolve(webIconsDir, 'favicon.512x512.png'));

  // Multi-resolution ICO (16, 32, 48, 64, 256)
  const ico16 = await sharp(roundedMaster).resize(16, 16).png().toBuffer();
  const ico32 = await sharp(roundedMaster).resize(32, 32).png().toBuffer();
  const ico48 = await sharp(roundedMaster).resize(48, 48).png().toBuffer();
  const ico64 = await sharp(roundedMaster).resize(64, 64).png().toBuffer();
  const ico256 = await sharp(roundedMaster).resize(256, 256).png().toBuffer();

  const icoBuffer = createIco([
    { w: 16, h: 16, data: ico16 },
    { w: 32, h: 32, data: ico32 },
    { w: 48, h: 48, data: ico48 },
    { w: 64, h: 64, data: ico64 },
    { w: 256, h: 256, data: ico256 },
  ]);
  writeFileSync(resolve(webIconsDir, 'favicon.ico'), icoBuffer);
  writeFileSync(resolve(workspace, 'apps/web/src/favicon.ico'), icoBuffer);

  // 3. Apple ICNS for macOS
  console.log('Generating macOS ICNS...');
  const iconsetDir = resolve(workspace, 'dist/mac-app.iconset');
  rmSync(iconsetDir, { recursive: true, force: true });
  mkdirSync(iconsetDir, { recursive: true });

  const macSpecs = [
    { name: 'icon_16x16.png', size: 16 },
    { name: 'icon_16x16@2x.png', size: 32 },
    { name: 'icon_32x32.png', size: 32 },
    { name: 'icon_32x32@2x.png', size: 64 },
    { name: 'icon_128x128.png', size: 128 },
    { name: 'icon_128x128@2x.png', size: 256 },
    { name: 'icon_256x256.png', size: 256 },
    { name: 'icon_256x256@2x.png', size: 512 },
    { name: 'icon_512x512.png', size: 512 },
    { name: 'icon_512x512@2x.png', size: 1024 },
  ];
  for (const s of macSpecs) {
    await sharp(roundedMaster)
      .resize(s.size, s.size)
      .toFile(resolve(iconsetDir, s.name));
  }
  execSync(`iconutil -c icns "${iconsetDir}" -o "${resolve(webIconsDir, 'favicon.icns')}"`);
  rmSync(iconsetDir, { recursive: true, force: true });

  // 4. Smart TV (LG webOS & Samsung Tizen)
  console.log('Generating Smart TV icons (LG webOS & Samsung Tizen)...');
  const tvPublicDir = resolve(workspace, 'apps/tv/public');
  mkdirSync(tvPublicDir, { recursive: true });
  await sharp(roundedMaster)
    .resize(80, 80)
    .toFile(resolve(tvPublicDir, 'icon.png'));
  await sharp(roundedMaster)
    .resize(130, 130)
    .toFile(resolve(tvPublicDir, 'large-icon.png'));

  // 5. Website icons & logo
  console.log('Generating website assets...');
  const websitePublicDir = resolve(workspace, 'apps/website/public');
  const websiteAssetsDir = resolve(workspace, 'apps/website/src/assets');
  mkdirSync(websitePublicDir, { recursive: true });
  mkdirSync(websiteAssetsDir, { recursive: true });

  await sharp(transparentMaster)
    .resize(256, 256)
    .toFile(resolve(websiteAssetsDir, 'logo.png'));
  await sharp(roundedMaster)
    .resize(16, 16)
    .toFile(resolve(websitePublicDir, 'favicon-16x16.png'));
  await sharp(roundedMaster)
    .resize(32, 32)
    .toFile(resolve(websitePublicDir, 'favicon-32x32.png'));
  await sharp(roundedMaster)
    .resize(256, 256)
    .toFile(resolve(websitePublicDir, 'favicon-256x256.png'));
  await sharp(roundedMaster)
    .resize(180, 180)
    .toFile(resolve(websitePublicDir, 'apple-touch-icon.png'));
  writeFileSync(resolve(websitePublicDir, 'favicon.ico'), icoBuffer);

  // Remote control web favicon
  const remotePublicDir = resolve(workspace, 'apps/remote-control-web/public');
  mkdirSync(remotePublicDir, { recursive: true });
  writeFileSync(resolve(remotePublicDir, 'favicon.ico'), icoBuffer);

  // 6. Android TV shell (Leanback banner, launcher icons, adaptive foreground)
  console.log('Generating Android TV shell assets...');
  const resDir = resolve(workspace, 'tv-shell/android/app/src/main/res');

  // Leanback 320x180 16:9 banner
  const birdContained = await sharp(transparentMaster)
    .resize(140, 140, { fit: 'contain' })
    .toBuffer();
  await sharp({
    create: {
      width: 320,
      height: 180,
      channels: 4,
      background: { r: 113, g: 96, b: 241, alpha: 1 },
    },
  })
    .composite([{ input: birdContained, gravity: 'center' }])
    .png()
    .toFile(resolve(resDir, 'drawable/banner.png'));

  // Adaptive launcher foreground (432x432, safe zone 260px)
  const birdAdaptive = await sharp(transparentMaster)
    .resize(260, 260, { fit: 'contain' })
    .toBuffer();
  await sharp({
    create: {
      width: 432,
      height: 432,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: birdAdaptive, gravity: 'center' }])
    .png()
    .toFile(resolve(resDir, 'drawable-nodpi/iptvnator_launcher_foreground.png'));

  // Update launcher background xml
  const backgroundXml = `<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="270" android:startColor="#7160F1" android:endColor="#5443DC" />
</shape>
`;
  writeFileSync(resolve(resDir, 'drawable/iptvnator_launcher_background.xml'), backgroundXml);

  // Android mipmap densities
  const mipmaps = [
    { dir: 'mipmap-mdpi', size: 80 },
    { dir: 'mipmap-hdpi', size: 120 },
    { dir: 'mipmap-xhdpi', size: 160 },
    { dir: 'mipmap-xxhdpi', size: 240 },
    { dir: 'mipmap-xxxhdpi', size: 320 },
  ];
  for (const m of mipmaps) {
    const dir = resolve(resDir, m.dir);
    mkdirSync(dir, { recursive: true });
    await sharp(roundedMaster)
      .resize(m.size, m.size)
      .toFile(resolve(dir, 'ic_launcher.png'));
    await sharp(circleMaster)
      .resize(m.size, m.size)
      .toFile(resolve(dir, 'ic_launcher_round.png'));
  }

  console.log('✅ All icons successfully generated for Windows, macOS, Linux, Web/PWA, LG webOS, Samsung Tizen, and Android TV!');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
