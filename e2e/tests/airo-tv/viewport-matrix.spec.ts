import { expect, test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { waitForFlutterReady } from '../helpers/flutter-selectors';

const artifactDir =
  process.env.AIRO_TV_VIEWPORT_ARTIFACT_DIR ??
  path.join(__dirname, '..', '..', '..', 'artifacts', 'airo-tv-browser-viewports');

const viewports = [
  {
    id: 'android-tv-1080p',
    label: 'Android TV 1080p',
    width: 1920,
    height: 1080,
    expectedText: /Airo TV|Search|Playlist|Help|Refresh|Airo News/i,
  },
  {
    id: 'android-tv-720p',
    label: 'Android TV 720p',
    width: 1280,
    height: 720,
    expectedText: /Airo TV|Search|Playlist|Help|Refresh|Airo News/i,
  },
  {
    id: 'android-tv-compact-browser',
    label: 'Android TV Compact Browser',
    width: 1024,
    height: 576,
    expectedText: /Search|Playlist|Help|Refresh|Airo News/i,
  },
  {
    id: 'mobile-browser-fallback',
    label: 'Mobile Browser Fallback',
    width: 390,
    height: 844,
    expectedText: /Airo News|IPTV|Channels|Playlist/i,
  },
] as const;

test.describe('Airo TV browser viewport release evidence', () => {
  for (const viewport of viewports) {
    test(`${viewport.label} renders without Flutter overflow`, async ({
      page,
    }) => {
      const consoleErrors: string[] = [];
      const pageErrors: string[] = [];

      page.on('console', (message) => {
        if (message.type() === 'error') {
          consoleErrors.push(message.text());
        }
      });
      page.on('pageerror', (error) => {
        pageErrors.push(error.message);
      });

      await page.setViewportSize({
        width: viewport.width,
        height: viewport.height,
      });

      await page.goto('/');
      await waitForFlutterReady(page, 60000);
      await page.waitForSelector('flt-glass-pane, canvas', {
        state: 'attached',
      });
      await expect(page.locator('body')).toBeVisible();
      await expect
        .poll(
          async () =>
            page
              .locator('flt-semantics, [role="button"], [role="heading"]')
              .count(),
          { timeout: 30000 },
        )
        .toBeGreaterThan(0);
      await expect(page.getByText(viewport.expectedText).first()).toBeVisible({
        timeout: 60000,
      });

      await expect
        .poll(
          async () =>
            page.evaluate(() =>
              Object.entries(window.localStorage)
                .filter(([key]) => key.includes('iptv'))
                .map(([key, value]) => `${key}=${value}`)
                .join('\n'),
            ),
          { timeout: 30000 },
        )
        .toContain('airo-tv-viewport.m3u');

      fs.mkdirSync(artifactDir, { recursive: true });
      const screenshotPath = path.join(
        artifactDir,
        `${viewport.id}-${viewport.width}x${viewport.height}.png`,
      );
      await page.screenshot({ path: screenshotPath, fullPage: true });
      expect(fs.statSync(screenshotPath).size).toBeGreaterThan(10000);

      const combinedErrors = [...consoleErrors, ...pageErrors];
      const overflowErrors = combinedErrors.filter((entry) =>
        /RenderFlex overflowed|A RenderFlex overflowed|EXCEPTION CAUGHT BY RENDERING LIBRARY/i.test(
          entry,
        ),
      );

      expect(overflowErrors).toEqual([]);
    });
  }
});
