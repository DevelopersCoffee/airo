/**
 * Google Authentication Setup Script
 *
 * This script opens a browser for manual Google login and saves the session.
 * Google blocks automated login, so manual intervention is required.
 *
 * Usage: npm run google:login
 *
 * After running, complete the Google login manually in the browser.
 * The session will be saved to googleAuth.json for reuse in tests.
 */

import { chromium } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';

const AUTH_FILE = path.join(__dirname, '..', 'googleAuth.json');
const LOGIN_TIMEOUT = 120_000; // 2 minutes for manual login

// Realistic Chrome user agent
const CHROME_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function setupGoogleAuth() {
  console.log('🔐 Google Authentication Setup');
  console.log('================================');
  console.log('');
  console.log('This will open a browser for you to login to Google manually.');
  console.log('Google blocks automated login, so you must complete this step by hand.');
  console.log('');

  // Launch browser with settings to avoid bot detection
  const browser = await chromium.launch({
    headless: false,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox',
      '--disable-dev-shm-usage',
    ],
  });

  // Create context with realistic user agent
  const context = await browser.newContext({
    userAgent: CHROME_USER_AGENT,
    viewport: { width: 1280, height: 720 },
    locale: 'en-US',
  });

  const page = await context.newPage();

  // Remove webdriver property to avoid detection
  await page.addInitScript(`
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  `);

  console.log('📱 Opening Google Sign-In page...');
  console.log('');

  // Navigate to Google accounts
  await page.goto('https://accounts.google.com/');

  console.log('👆 Please complete the login in the browser window.');
  console.log('   - Enter your Google email');
  console.log('   - Enter your password');
  console.log('   - Complete 2FA if prompted');
  console.log('');
  console.log(`⏱️  You have ${LOGIN_TIMEOUT / 1000} seconds to complete login...`);
  console.log('');

  // Wait for user to complete login (check for successful sign-in)
  try {
    await page.waitForURL('**/myaccount.google.com/**', { timeout: LOGIN_TIMEOUT });
    console.log('✅ Login successful! Detected redirect to myaccount.google.com');
  } catch {
    // User might have navigated elsewhere, check if logged in
    const cookies = await context.cookies();
    const hasAuthCookies = cookies.some((c: { name: string }) =>
      c.name.includes('SAPISID') ||
      c.name.includes('SID') ||
      c.name.includes('HSID')
    );

    if (hasAuthCookies) {
      console.log('✅ Login appears successful (auth cookies found)');
    } else {
      console.log('⚠️  Could not confirm login. Saving session anyway...');
    }
  }

  // Save the session state
  console.log('');
  console.log('💾 Saving session to googleAuth.json...');

  await context.storageState({ path: AUTH_FILE });

  // Verify file was created
  if (fs.existsSync(AUTH_FILE)) {
    const stats = fs.statSync(AUTH_FILE);
    console.log(`✅ Session saved successfully (${stats.size} bytes)`);
  } else {
    console.log('❌ Failed to save session file');
  }

  // Close browser
  await browser.close();

  console.log('');
  console.log('🎉 Setup complete!');
  console.log('');
  console.log('You can now run tests that require Google authentication:');
  console.log('  npm run test:auth');
  console.log('');
  console.log('Note: If Google invalidates your session, run this script again.');
}

// Run the setup
setupGoogleAuth().catch(console.error);

