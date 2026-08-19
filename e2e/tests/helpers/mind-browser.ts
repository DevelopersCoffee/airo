import { expect, type Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import {
  enableFlutterAccessibility,
  waitForFlutterReady,
} from './flutter-selectors';

export const mindViewports = [
  { id: 'desktop-1440', width: 1440, height: 900 },
  { id: 'desktop-1920', width: 1920, height: 1080 },
  { id: 'tablet-1280', width: 1280, height: 720 },
  { id: 'mobile-390', width: 390, height: 844 },
] as const;

export type MindViewport = (typeof mindViewports)[number];

export function mindArtifactDir(): string {
  return (
    process.env.AIRO_MIND_ARTIFACT_DIR ??
    path.join(__dirname, '..', '..', '..', 'artifacts', 'airo-mind-browser')
  );
}

export function mindBrandingDir(): string {
  return path.join(mindArtifactDir(), 'branding');
}

export async function openMindRoute(
  page: Page,
  hashRoute: string,
  viewport: MindViewport = mindViewports[0],
): Promise<void> {
  page.on('console', (message) => {
    if (message.type() === 'error') {
      console.log(`[browser:error] ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => console.log(`[browser:pageerror] ${error}`));

  await page.setViewportSize(viewport);
  await page.goto(`/#${hashRoute}`, { waitUntil: 'domcontentloaded' });
  await waitForFlutterReady(page, 120000);
  await enableFlutterAccessibility(page);
  await expect
    .poll(
      async () => {
        const textLen = (await page.locator('body').innerText()).trim().length;
        if (textLen >= 8) return true;
        const semantics = await page
          .locator(
            '[role="heading"], [role="tab"], [role="button"], flt-semantics',
          )
          .count();
        return semantics > 0;
      },
      { timeout: 120000 },
    )
    .toBe(true);
}

export async function tapMindNav(page: Page, label: string): Promise<void> {
  const nav = page.getByRole('tab', { name: label, exact: true });
  await expect(nav).toBeVisible({ timeout: 60000 });
  await nav.click();
  await page.waitForTimeout(800);
}

export async function captureMindScreenshot(
  page: Page,
  filename: string,
  subdir = 'branding',
): Promise<string> {
  const dir = path.join(mindArtifactDir(), subdir);
  fs.mkdirSync(dir, { recursive: true });
  const target = path.join(dir, filename);
  await page.screenshot({
    path: target,
    animations: 'disabled',
    fullPage: false,
  });
  return target;
}

/** Scribe home may show the library or a model bootstrap screen on web. */
export async function waitForScribeShell(page: Page): Promise<void> {
  const candidates = [
    page.getByText('Airo Mind').first(),
    page.getByText(/Download|On-device models|Getting ready/i).first(),
    page.getByRole('button', { name: /Record/i }).first(),
  ];
  await expect
    .poll(
      async () => {
        for (const locator of candidates) {
          if (await locator.isVisible().catch(() => false)) {
            return true;
          }
        }
        return false;
      },
      { timeout: 120000 },
    )
    .toBe(true);
}
