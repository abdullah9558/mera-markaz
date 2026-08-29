import { spawn } from 'node:child_process';
import { watch } from 'node:fs';
import path from 'node:path';

const appRoot = process.env.MERA_MARKAZ_APP_DIR || path.resolve(process.cwd(), '..', 'app');
const run = () => spawn('npm', ['run', 'sync:app'], { cwd: process.cwd(), stdio: 'inherit', shell: true });
let timer;
watch(appRoot, { recursive: true }, (_event, filename) => {
  if (!filename || (!filename.endsWith('.dart') && !filename.endsWith('.yaml') && !filename.includes('assets'))) return;
  clearTimeout(timer);
  timer = setTimeout(run, 700);
});
run();
console.log(`Watching ${appRoot}. Keep this window open while editing the Flutter app.`);
