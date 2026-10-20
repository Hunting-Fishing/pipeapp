import { createHash } from 'node:crypto';
import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

// Run after: flutter build web --release --no-web-resources-cdn --pwa-strategy=none
// No external packages or server are required by this post-build step.
const directory = fileURLToPath(new URL('../build/web/', import.meta.url));
// CanvasKit downloads its default Roboto from Google unless this exact family
// is declared, even when every visible theme style uses a bundled alias.
const fontManifest = JSON.parse(await readFile(join(directory, 'assets/FontManifest.json'), 'utf8'));
if (!Array.isArray(fontManifest) || !fontManifest.some(family =>
    family.family === 'Roboto' && Array.isArray(family.fonts) && family.fonts.length > 0)) {
  throw new Error('The offline game requires a bundled canonical Roboto font family. Rebuild after declaring it in pubspec.yaml.');
}
const files = [];
async function walk(relative = '') {
  for (const name of await readdir(join(directory, relative))) {
    const key = relative ? `${relative}/${name}` : name;
    const entry = join(directory, key);
    if ((await stat(entry)).isDirectory()) await walk(key);
    else if (!key.endsWith('.map') &&
             !['service_worker.js', 'offline-manifest.json', 'flutter_service_worker.js'].includes(key)) files.push(key);
  }
}
await walk();
files.sort();
if (!files.includes('main.dart.js') || !files.includes('index.html')) {
  throw new Error('Build the Flutter web release before preparing its offline bundle.');
}
const hash = createHash('sha256');
let bytes = 0;
for (const file of files) {
  const content = await readFile(join(directory, file));
  bytes += content.length;
  hash.update(file).update(content);
}
const revision = hash.digest('hex').slice(0, 20);
const source = `// Generated offline bundle. Rebuild with tool/prepare_offline_web.mjs.
const prefix = 'oil-gas-tycoon:' + self.registration.scope + ':';
const cacheName = prefix + ${JSON.stringify(revision)};
const root = new URL('./', self.location.href);
const files = ${JSON.stringify(files)};
const urls = files.map(file => new URL(file, root).href);

self.addEventListener('install', event => {
  // The filenames are stable across Flutter releases. Bypass the browser's
  // HTTP cache so a new revision cannot accidentally precache stale code or
  // a mix of old and new assets beneath its new cache name.
  const requests = urls.map(url => new Request(url, { cache: 'reload' }));
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(requests)));
  // An update waits for the prior session to close; a running company keeps
  // one consistent code/assets version for the duration of the session.
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(prefix) && name !== cacheName) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== root.origin ||
      !url.href.startsWith(root.href)) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    const key = event.request.mode === 'navigate'
      ? new URL('index.html', root).href : event.request;
    const cached = await cache.match(key, { ignoreSearch: true });
    if (cached) return cached;
    return fetch(event.request);
  })());
});
`;
await writeFile(join(directory, 'service_worker.js'), source);
await writeFile(join(directory, 'offline-manifest.json'),
  JSON.stringify({ revision, fileCount: files.length, bytes, files }, null, 2) + '\n');
console.log(`Offline web bundle ${revision}: ${files.length} files, ${(bytes / 1048576).toFixed(1)} MiB.`);
