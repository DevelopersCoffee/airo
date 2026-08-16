import { expect, test } from '@playwright/test';
import {
  enableFlutterAccessibility,
  waitForFlutterReady,
} from '../helpers/flutter-selectors';

/**
 * Airo Mind shell smoke tests (Flutter web build).
 *
 * Uses hash routes because the static web server does not rewrite paths.
 * Validates the Mind title, route wiring, and the desktop assistant catalog.
 *
 * Run via: scripts/validate_airo_mind_browser.sh
 */

async function openMindRoute(
  page: import('@playwright/test').Page,
  hashRoute: string,
) {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(`/#${hashRoute}`);
  await waitForFlutterReady(page, 90000);
  await enableFlutterAccessibility(page);
  await expect
    .poll(
      async () => (await page.locator('body').innerText()).trim().length,
      { timeout: 90000 },
    )
    .toBeGreaterThan(10);
}

test.describe('Airo Mind shell @smoke', () => {
  test('uses the Airo Mind product title', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    // validate_airo_mind_browser.sh patches index.html; MaterialApp.title may lag.
    await expect(page).toHaveTitle(/Airo Mind/i);
  });

  test('mounts Mind shell routes', async ({ page }) => {
    await openMindRoute(page, '/mind');
    await expect(page.getByText('Airo AI Lab')).toBeVisible({ timeout: 60000 });
    await expect(page.getByText('Audio Scribe')).toBeVisible();

    await openMindRoute(page, '/models');
    await expect(page.getByText('On-device models')).toBeVisible({
      timeout: 60000,
    });

    await openMindRoute(page, '/wellbeing');
    await expect(
      page.getByRole('heading', { name: 'Wellbeing' }),
    ).toBeVisible({ timeout: 60000 });
  });

  test('assistant hub hides phone-only skills on desktop Mind', async ({
    page,
  }) => {
    await openMindRoute(page, '/mind');

    await expect(page.getByText('AI Chat')).toBeVisible();
    await expect(page.getByText('Audio Scribe')).toBeVisible();
    await expect(page.getByText('Prompt Lab')).toBeVisible();

    await expect(page.getByText('Ask Image')).toHaveCount(0);
    await expect(page.getByText('Mobile Actions & Tiny Garden')).toHaveCount(0);
  });

  test('chat prompt chips omit mobile-only skills', async ({ page }) => {
    await openMindRoute(page, '/mind/chat');

    await expect(
      page.getByRole('checkbox', { name: 'Diet Plan' }),
    ).toBeVisible({ timeout: 90000 });
    await expect(
      page.getByRole('checkbox', { name: 'Audio Scribe' }),
    ).toBeVisible();

    await expect(page.getByRole('checkbox', { name: 'Mobile Actions' })).toHaveCount(0);
    await expect(page.getByRole('checkbox', { name: 'Tiny Garden' })).toHaveCount(0);
    await expect(page.getByRole('checkbox', { name: 'Ask Image' })).toHaveCount(0);
    await expect(page.getByRole('checkbox', { name: 'Arena Games' })).toHaveCount(0);
  });

  test('models route exposes on-device catalog on desktop Mind', async ({
    page,
  }) => {
    await openMindRoute(page, '/models');
    await expect(page.getByText('On-device models')).toBeVisible({
      timeout: 60000,
    });
    await expect(page.getByText(/Gemma|Qwen|Download/i).first()).toBeVisible({
      timeout: 60000,
    });
  });
});
