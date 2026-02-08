import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';

/**
 * Playwright configuration for Airo Flutter Web E2E tests
 *
 * Authentication Strategy:
 * - Demo login (admin/admin): Used for most tests, no external dependencies
 * - Google OAuth: Requires manual session setup via `npm run google:login`
 *
 * Project Structure:
 * - setup: Authenticates and saves session state
 * - chromium/firefox/webkit: Run tests with saved auth state
 * - no-auth: Tests that don't require authentication (login page tests)
 */

// Auth state file paths
const DEMO_AUTH_FILE = path.join(__dirname, '.auth', 'demoAuth.json');
const GOOGLE_AUTH_FILE = path.join(__dirname, 'googleAuth.json');

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    // Base URL for Flutter Web app (run `flutter run -d chrome --web-port=8080`)
    baseURL: process.env.FLUTTER_WEB_URL || 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  // Timeout for each test
  timeout: 60000,
  expect: {
    timeout: 10000,
  },

  projects: [
    // Setup project - runs first to authenticate
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },

    // No-auth tests (login page, registration, etc.)
    {
      name: 'no-auth',
      testMatch: /auth\.spec\.ts/,
      use: { ...devices['Desktop Chrome'] },
    },

    // Authenticated tests - depend on setup
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: DEMO_AUTH_FILE,
      },
      dependencies: ['setup'],
      testIgnore: /auth\.spec\.ts/,
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: DEMO_AUTH_FILE,
      },
      dependencies: ['setup'],
      testIgnore: /auth\.spec\.ts/,
    },
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        storageState: DEMO_AUTH_FILE,
      },
      dependencies: ['setup'],
      testIgnore: /auth\.spec\.ts/,
    },

    // Google OAuth tests - uses manually saved session
    {
      name: 'google-auth',
      testMatch: /google-auth\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: GOOGLE_AUTH_FILE,
      },
    },

    // Mobile viewports (authenticated)
    {
      name: 'Mobile Chrome',
      use: {
        ...devices['Pixel 5'],
        storageState: DEMO_AUTH_FILE,
      },
      dependencies: ['setup'],
      testIgnore: /auth\.spec\.ts/,
    },
    {
      name: 'Mobile Safari',
      use: {
        ...devices['iPhone 12'],
        storageState: DEMO_AUTH_FILE,
      },
      dependencies: ['setup'],
      testIgnore: /auth\.spec\.ts/,
    },
  ],

  // Web server to run before tests (optional - if you want auto-start)
  // webServer: {
  //   command: 'cd ../app && flutter run -d chrome --web-port=8080 --web-renderer=html',
  //   url: 'http://localhost:8080',
  //   reuseExistingServer: !process.env.CI,
  //   timeout: 120000,
  // },
});

