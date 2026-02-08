import { test as setup, expect } from '@playwright/test';
import { waitForFlutterReady } from './helpers/flutter-selectors';
import * as path from 'path';
import * as fs from 'fs';

/**
 * Authentication Setup
 * 
 * This setup file runs before authenticated tests to:
 * 1. Login with demo credentials (admin/admin)
 * 2. Save the authenticated session state
 * 
 * The saved state is reused by all authenticated test projects,
 * improving test performance by avoiding repeated logins.
 */

const AUTH_DIR = path.join(__dirname, '..', '.auth');
const DEMO_AUTH_FILE = path.join(AUTH_DIR, 'demoAuth.json');

// Ensure auth directory exists
if (!fs.existsSync(AUTH_DIR)) {
  fs.mkdirSync(AUTH_DIR, { recursive: true });
}

setup('authenticate with demo credentials', async ({ page }) => {
  // Navigate to login page
  await page.goto('/');
  await waitForFlutterReady(page);

  // Wait for login form to be visible
  await expect(page.getByText('Welcome to Airo')).toBeVisible({ timeout: 15000 });

  // Check if demo credentials button exists and click it
  const demoButton = page.getByText('Fill Demo Credentials');
  const hasDemoButton = await demoButton.isVisible().catch(() => false);

  if (hasDemoButton) {
    // Use demo button to fill credentials
    await demoButton.click();
    await page.waitForTimeout(500);
  } else {
    // Manually enter demo credentials using role-based selectors
    // Flutter exposes text fields with role="textbox"
    const textboxes = page.getByRole('textbox');
    const usernameField = textboxes.first();
    const passwordField = textboxes.nth(1);

    await usernameField.fill('demo');
    await passwordField.fill('demo123');
  }

  // Click Sign In button - use getByRole to avoid matching "Sign in to continue" subtitle
  const signInButton = page.getByRole('button', { name: 'Sign In' });
  await expect(signInButton).toBeVisible();
  await signInButton.click();

  // Wait for navigation to agent page (successful login)
  await page.waitForURL('**/agent**', { timeout: 15000 });

  // Verify we're on the agent page
  const currentUrl = page.url();
  expect(currentUrl).toContain('/agent');

  console.log('✅ Demo login successful, saving session state...');

  // Save the authenticated state
  await page.context().storageState({ path: DEMO_AUTH_FILE });

  console.log(`✅ Session saved to ${DEMO_AUTH_FILE}`);
});

setup('verify auth file exists', async () => {
  // Verify the auth file was created
  expect(fs.existsSync(DEMO_AUTH_FILE)).toBeTruthy();
  
  const stats = fs.statSync(DEMO_AUTH_FILE);
  expect(stats.size).toBeGreaterThan(0);
  
  console.log(`✅ Auth file verified: ${stats.size} bytes`);
});

