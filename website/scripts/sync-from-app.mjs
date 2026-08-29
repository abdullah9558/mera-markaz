import { cp, mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const siteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const appRoot = process.env.MERA_MARKAZ_APP_DIR || path.resolve(siteRoot, '..', 'app');
const pubspecPath = path.join(appRoot, 'pubspec.yaml');
if (!existsSync(pubspecPath)) throw new Error(`Mera Markaz app not found at ${appRoot}. Set MERA_MARKAZ_APP_DIR to its folder.`);

const pubspec = await readFile(pubspecPath, 'utf8');
const versionMatch = pubspec.match(/^version:\s*([^+\s]+)(?:\+(\S+))?/m);
const featuresRoot = path.join(appRoot, 'lib', 'features');
const modules = (await readdir(featuresRoot, { withFileTypes: true })).filter(entry => entry.isDirectory() && entry.name !== 'premium').map(entry => entry.name).sort();
const data = { name: 'Mera Markaz', version: versionMatch?.[1] ?? 'unknown', build: versionMatch?.[2] ?? 'unknown', lastSynced: new Date().toISOString(), modules };
await mkdir(path.join(siteRoot, 'content'), { recursive: true });
await writeFile(path.join(siteRoot, 'content', 'app-data.json'), `${JSON.stringify(data, null, 2)}\n`);

const sourceBranding = path.join(appRoot, 'assets', 'branding');
const destinationMedia = path.join(siteRoot, 'public', 'media');
await mkdir(destinationMedia, { recursive: true });
for (const name of ['meramarkaz-logo.png', 'meramarkaz-thumbnail.png']) {
  const source = path.join(sourceBranding, name);
  if (existsSync(source)) await cp(source, path.join(destinationMedia, name));
}
const screenshots = path.join(appRoot, 'assets', 'screenshots');
if (existsSync(screenshots)) await cp(screenshots, path.join(destinationMedia, 'screenshots'), { recursive: true, force: true });
console.log(`Synced Mera Markaz ${data.version}+${data.build} and ${modules.length} app modules.`);
