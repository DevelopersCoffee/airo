import { expect, test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { waitForFlutterReady } from '../helpers/flutter-selectors';

const rawDir =
  process.env.AIRO_STORE_SCREENSHOT_RAW_DIR ??
  path.join(__dirname, '..', '..', '..', 'artifacts', 'store-listing', 'raw');

const viewports = [
  { id: 'tv-1080p', width: 1920, height: 1080 },
  { id: 'tablet-720p', width: 1280, height: 720 },
  { id: 'mobile-portrait', width: 390, height: 844 },
] as const;

async function openRuntime(
  page: import('@playwright/test').Page,
  viewport: (typeof viewports)[number],
) {
  page.on('console', (message) => {
    if (message.type() === 'error' || message.type() === 'warning') {
      console.log(`[browser:${message.type()}] ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => console.log(`[browser:pageerror] ${error}`));
  await page.setViewportSize(viewport);
  await page.goto('/');
  await waitForFlutterReady(page, 60000);
  await expect(page.getByText(/Airo News/i).first()).toBeVisible({
    timeout: 60000,
  });
}

async function capture(
  page: import('@playwright/test').Page,
  filename: string,
) {
  fs.mkdirSync(rawDir, { recursive: true });
  await page.screenshot({
    path: path.join(rawDir, filename),
    animations: 'disabled',
    fullPage: false,
  });
}

test.describe('Airo TV store screenshots', () => {
  for (const viewport of viewports) {
    test(`captures live browse UI at ${viewport.width}x${viewport.height}`, async ({
      page,
    }) => {
      await openRuntime(page, viewport);
      await capture(
        page,
        `browse-${viewport.id}-${viewport.width}x${viewport.height}.png`,
      );
    });
  }

  test('captures Search from the live TV runtime', async ({ page }) => {
    const viewport = viewports[0];
    await openRuntime(page, viewport);

    await page.getByText(/^Search$/).first().click();
    await expect(
      page.getByRole('textbox', { name: 'Type a channel name' }),
    ).toBeVisible();
    await capture(page, 'search-tv-1080p-1920x1080.png');
  });

  test('captures the player from the live TV runtime', async ({ page }) => {
    const viewport = viewports[0];
    await openRuntime(page, viewport);
    await page
      .getByRole('button', { name: 'Airo News', exact: true })
      .click();
    await page.waitForTimeout(1500);
    await capture(page, 'player-tv-1080p-1920x1080.png');
  });

  test('captures Guide from the live TV runtime', async ({ page }) => {
    const viewport = viewports[0];
    await openRuntime(page, viewport);
    const guide = page.getByRole('button', { name: /^TV Guide Guide$/ });
    await expect(guide).toBeVisible();
    await guide.click();
    await expect(page.getByText(/Search the guide|Guide/i).first()).toBeVisible();
    await capture(page, 'guide-tv-1080p-1920x1080.png');
  });
});
