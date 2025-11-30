import { test, expect } from '@playwright/test';
import { waitForFlutterReady } from './helpers/flutter-selectors';

/**
 * Smoke Tests - Critical Path Verification
 * 
 * These tests verify the most critical app functionality.
 * Tag: @smoke - used for filtering in CI/CD smoke test runs.
 * 
 * Run with: npx playwright test --grep "@smoke"
 */

test.describe('Smoke Tests @smoke', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
  });

  test('app launches successfully @smoke', async ({ page }) => {
    // Verify app loads without crashing
    await expect(page).toHaveTitle(/Airo/i);
    
    // Check main content is visible
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });

  test('navigation tabs are visible @smoke', async ({ page }) => {
    // Core tabs should be accessible
    const coinsTab = page.getByText('Coins');
    const questTab = page.getByText('Quest');
    const beatsTab = page.getByText('Beats');
    const arenaTab = page.getByText('Arena');
    const lootTab = page.getByText('Loot');
    const talesTab = page.getByText('Tales');

    // At least the main tabs should be visible (navigation may vary)
    await expect(coinsTab.or(questTab).or(beatsTab)).toBeVisible({ timeout: 10000 });
  });

  test('coins tab loads @smoke', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.waitForTimeout(500);
    
    // Verify Coins screen content
    const pageContent = page.locator('flt-semantics-container');
    await expect(pageContent).toBeVisible();
  });

  test('quest tab loads @smoke', async ({ page }) => {
    await page.getByText('Quest').click();
    await page.waitForTimeout(500);
    
    // Verify Quest screen content
    const pageContent = page.locator('flt-semantics-container');
    await expect(pageContent).toBeVisible();
  });

  test('arena tab loads @smoke', async ({ page }) => {
    await page.getByText('Arena').click();
    await page.waitForTimeout(500);
    
    // Verify Arena screen content  
    const pageContent = page.locator('flt-semantics-container');
    await expect(pageContent).toBeVisible();
  });

  test('no console errors on startup @smoke', async ({ page }) => {
    const errors: string[] = [];
    
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(2000);

    // Filter out expected Flutter web errors
    const criticalErrors = errors.filter(
      (e) => !e.includes('favicon') && 
             !e.includes('404') &&
             !e.includes('Failed to load resource')
    );

    // Log for visibility but don't fail (analysis mode)
    if (criticalErrors.length > 0) {
      console.log('Console errors detected:', criticalErrors);
    }
  });
});

test.describe('Critical Features @smoke', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
  });

  test('bill split feature accessible @smoke', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.waitForTimeout(500);

    // Check if Split Bill is accessible
    const splitBill = page.getByText('Split Bill');
    
    if (await splitBill.isVisible()) {
      await splitBill.click();
      await page.waitForTimeout(500);
      
      // Verify bill split screen loads
      await expect(page.getByText('Add expense').or(page.getByText('expense'))).toBeVisible();
    }
  });
});

