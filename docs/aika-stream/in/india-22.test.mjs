import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const css = readFileSync(
  new URL('../../assets/airo-tv/india-22.css', import.meta.url),
  'utf8',
);
assert.match(css, /#070A12/);
assert.match(css, /\.tv-bezel/);
assert.match(css, /prefers-reduced-motion:\s*reduce/);
assert.equal((css.match(/linear-gradient\(/g) || []).length, 0);
assert.match(css, /\.tv-stage[\s\S]*radial-gradient/);

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
assert.match(html, /Your TV\. Reimagined\./);
assert.match(html, /Watch Aika Stream/);
assert.match(html, /Explore Features/);
assert.match(html, /01-tv-home-channel-grid\.png/);
assert.doesNotMatch(html, /aika-stream-split-screen-banner\.jpg/);
assert.doesNotMatch(html, /Download APK/);
