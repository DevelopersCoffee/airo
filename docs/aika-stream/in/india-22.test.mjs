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
