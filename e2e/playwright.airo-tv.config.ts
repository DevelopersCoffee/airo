import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';

const webPort = Number(process.env.AIRO_TV_WEB_PORT ?? '8790');
const baseURL = process.env.FLUTTER_WEB_URL ?? `http://127.0.0.1:${webPort}`;
const artifactDir =
  process.env.AIRO_TV_VIEWPORT_ARTIFACT_DIR ??
  path.join(__dirname, '..', 'artifacts', 'airo-tv-browser-viewports');
const useSystemChrome = process.env.AIRO_TV_USE_SYSTEM_CHROME === '1';

export default defineConfig({
  testDir: './tests/airo-tv',
  fullyParallel: false,
  retries: 0,
  workers: 1,
  reporter: [['list']],
  outputDir: path.join(artifactDir, 'playwright-results'),
  timeout: 90000,
  expect: {
    timeout: 15000,
  },
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'airo-tv-browser-viewports',
      use: {
        ...devices['Desktop Chrome'],
        ...(useSystemChrome ? { channel: 'chrome' as const } : {}),
      },
    },
  ],
  webServer: {
    command: `python3 -m http.server ${webPort} --bind 127.0.0.1 --directory ${path.join(
      __dirname,
      '..',
      'app',
      'build',
      'web',
    )}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
