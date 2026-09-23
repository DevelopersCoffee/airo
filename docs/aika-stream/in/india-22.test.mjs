import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { startIndiaMotion } from '../../assets/airo-tv/india-22.js';

const css = readFileSync(
  new URL('../../assets/airo-tv/india-22.css', import.meta.url),
  'utf8',
);
assert.match(css, /#070A12/);
assert.match(css, /\.tv-bezel/);
assert.match(css, /prefers-reduced-motion:\s*reduce/);
assert.equal((css.match(/linear-gradient\(/g) || []).length, 0);
assert.match(css, /\.tv-stage[\s\S]*radial-gradient/);
assert.match(
  css,
  /\.india-page \.hero::before,\s*\.india-page \.hero::after\s*\{[^}]*display:\s*none/,
);
assert.match(css, /\.india-page \.hero::before[\s\S]*content:\s*none/);
assert.match(css, /\.india-page \.hero::after[\s\S]*background:\s*none/);

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
assert.match(html, /Your TV\. Reimagined\./);
assert.match(html, /Watch Aika Stream/);
assert.match(html, /Explore Features/);
assert.match(html, /01-tv-home-channel-grid\.png/);
assert.doesNotMatch(html, /aika-stream-split-screen-banner\.jpg/);
assert.doesNotMatch(html, /Download APK/);

for (const heading of [
  'Watch more. At the same time.',
  'One screen. Everything you watch.',
  'Pick up where you left off.',
  'Designed for your TV.',
  'Simple enough for everyone.',
  'Everything you watch. In one place.',
  'One screen. Endless possibilities.',
  'Turn on your TV.',
]) {
  assert.match(html, new RegExp(heading.replace(/[.]/g, '\\.')));
}
assert.match(html, /data-panes="4"/);
assert.match(html, /does not sell, host, or provide television channels/);
assert.doesNotMatch(html, /India vs Afghanistan/);

function makeClassList() {
  const classes = new Set();
  return {
    add(name) {
      classes.add(name);
    },
    toggle(name, force) {
      if (force) classes.add(name);
      else classes.delete(name);
    },
    has(name) {
      return classes.has(name);
    },
  };
}

const motionStage = { dataset: {} };
const motionCards = Array.from({ length: 4 }, () => ({
  classList: makeClassList(),
}));
const motionRoot = {
  querySelector(selector) {
    if (selector === '[data-india-multiview]') return motionStage;
    return null;
  },
  querySelectorAll(selector) {
    if (selector === '.cw-card') return motionCards;
    return [];
  },
};

let tickMotion;
startIndiaMotion(motionRoot, { matches: false }, (fn) => {
  tickMotion = fn;
  return 0;
});

assert.equal(motionStage.dataset.panes, '1');
assert.equal(motionCards[0].classList.has('is-selected'), true);

const paneSequence = ['2', '4', '1', '2'];
const cardSequence = [1, 2, 3, 0];
for (let i = 0; i < 4; i += 1) {
  tickMotion();
  assert.equal(motionStage.dataset.panes, paneSequence[i]);
  assert.equal(motionCards[cardSequence[i]].classList.has('is-selected'), true);
  for (let j = 0; j < 4; j += 1) {
    if (j !== cardSequence[i]) {
      assert.equal(motionCards[j].classList.has('is-selected'), false);
    }
  }
}
