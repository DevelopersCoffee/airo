import { test } from '@playwright/test';
import {
  captureMindScreenshot,
  mindViewports,
  openMindRoute,
  tapMindNav,
  waitForScribeShell,
} from '../helpers/mind-browser';
import {
  printMindE2ESummary,
  recordMindStep,
} from '../helpers/mind-e2e-report';

/**
 * Branding / store-evidence screenshots for Airo Mind (Flutter web build).
 *
 * Run via:
 *   scripts/validate_airo_mind_browser.sh mind-branding-screenshots.spec.ts
 */

const primaryViewport = mindViewports[0];

test.describe('Airo Mind branding screenshots', () => {
  test.afterAll(() => {
    printMindE2ESummary();
  });

  test('scribe home @branding', async ({ page }) => {
    await openMindRoute(page, '/', primaryViewport);
    await waitForScribeShell(page);
    const file = await captureMindScreenshot(
      page,
      `scribe-home-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-scribe',
      phase: 'Branding',
      label: `Scribe home → ${file}`,
      status: 'pass',
    });
  });

  test('assistant hub @branding', async ({ page }) => {
    await openMindRoute(page, '/mind', primaryViewport);
    const file = await captureMindScreenshot(
      page,
      `assistant-hub-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-assistant',
      phase: 'Branding',
      label: `Assistant hub → ${file}`,
      status: 'pass',
    });
  });

  test('audio scribe @branding', async ({ page }) => {
    await openMindRoute(page, '/mind/audio-scribe', primaryViewport);
    const file = await captureMindScreenshot(
      page,
      `audio-scribe-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-audio-scribe',
      phase: 'Branding',
      label: `Audio Scribe → ${file}`,
      status: 'pass',
    });
  });

  test('prompt lab @branding', async ({ page }) => {
    await openMindRoute(page, '/mind/prompt-lab', primaryViewport);
    const file = await captureMindScreenshot(
      page,
      `prompt-lab-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-prompt-lab',
      phase: 'Branding',
      label: `Prompt Lab → ${file}`,
      status: 'pass',
    });
  });

  test('models catalog @branding', async ({ page }) => {
    await openMindRoute(page, '/models', primaryViewport);
    const file = await captureMindScreenshot(
      page,
      `models-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-models',
      phase: 'Branding',
      label: `Models → ${file}`,
      status: 'pass',
    });
  });

  test('wellbeing @branding', async ({ page }) => {
    await openMindRoute(page, '/wellbeing', primaryViewport);
    const file = await captureMindScreenshot(
      page,
      `wellbeing-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-wellbeing',
      phase: 'Branding',
      label: `Wellbeing → ${file}`,
      status: 'pass',
    });
  });

  test('shell navigation chrome @branding', async ({ page }) => {
    await openMindRoute(page, '/mind', primaryViewport);
    await tapMindNav(page, 'Scribe');
    await waitForScribeShell(page);
    const file = await captureMindScreenshot(
      page,
      `shell-nav-${primaryViewport.id}.png`,
    );
    recordMindStep({
      id: 'brand-shell-nav',
      phase: 'Branding',
      label: `Bottom nav → ${file}`,
      status: 'pass',
    });
  });

  for (const viewport of mindViewports) {
    test(`hero assistant at ${viewport.width}x${viewport.height} @branding`, async ({
      page,
    }) => {
      await openMindRoute(page, '/mind', viewport);
      const file = await captureMindScreenshot(
        page,
        `assistant-hero-${viewport.id}-${viewport.width}x${viewport.height}.png`,
      );
      recordMindStep({
        id: `brand-hero-${viewport.id}`,
        phase: 'Branding',
        label: `Hero ${viewport.id} → ${file}`,
        status: 'pass',
      });
    });
  }
});
