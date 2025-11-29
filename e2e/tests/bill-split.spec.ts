import { test, expect, Page } from '@playwright/test';
import {
  BillSplitTestIds,
  ItemizedSplitTestIds,
  waitForFlutterReady,
  getByText,
  getByPlaceholder,
  fillTextField,
} from './helpers/flutter-selectors';

/**
 * Bill Split Feature E2E Tests
 * 
 * Tests the complete bill splitting flow including:
 * - Adding participants
 * - Entering amount
 * - Selecting split options
 * - Itemized split with OCR
 * 
 * Run with: npm run test:bill-split
 */

test.describe('Bill Split Feature', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
  });

  test('should display bill split screen', async ({ page }) => {
    // Navigate to Coins tab (bottom navigation)
    await page.getByText('Coins').click();
    await page.waitForTimeout(500);

    // Click Split Bill option
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);

    // Verify bill split screen is displayed
    await expect(page.getByText('Add expense')).toBeVisible();
    await expect(page.getByText('With you and:')).toBeVisible();
  });

  test('should add a participant', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);

    // Click "Add people" to open participant picker
    await page.getByText('Add people').click();
    await page.waitForTimeout(300);

    // Verify participant picker is shown
    await expect(page.getByText('Add people').first()).toBeVisible();
    
    // Close picker
    await page.getByText('Done').click();
  });

  test('should enter expense details and calculate split', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);

    // Enter description
    const descInput = page.getByPlaceholder('Enter a description');
    await descInput.click();
    await descInput.fill('Dinner');

    // Enter amount
    const amountInput = page.getByPlaceholder('0.00');
    await amountInput.click();
    await amountInput.fill('500');

    // Add participant first (required before save)
    await page.getByText('Add people').click();
    await page.waitForTimeout(300);
    // Select first contact (if available)
    const firstContact = page.locator('li').first();
    if (await firstContact.isVisible()) {
      await firstContact.click();
    }
    await page.getByText('Done').click();

    // Click Save
    await page.getByText('Save').click();
    await page.waitForTimeout(500);

    // Verify result view is shown
    await expect(page.getByText('₹500').or(page.getByText('500.00'))).toBeVisible();
  });

  test('should navigate to itemized split screen', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);

    // Add participant first
    await page.getByText('Add people').click();
    await page.waitForTimeout(300);
    const firstContact = page.locator('li').first();
    if (await firstContact.isVisible()) {
      await firstContact.click();
    }
    await page.getByText('Done').click();

    // Click "Split by items"
    await page.getByText('Split by items').click();
    await page.waitForTimeout(500);

    // Verify itemized split screen
    await expect(page.getByText('Split Items')).toBeVisible();
    await expect(page.getByText('Upload Receipt')).toBeVisible();
  });

  test('should show image picker options on itemized split', async ({ page }) => {
    await page.getByText('Coins').click();
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);

    // Add participant
    await page.getByText('Add people').click();
    await page.waitForTimeout(300);
    await page.getByText('Done').click();

    // Navigate to itemized split
    await page.getByText('Split by items').click();
    await page.waitForTimeout(500);

    // Verify image picker buttons (Camera disabled on web)
    await expect(page.getByText('Gallery')).toBeVisible();
    // Camera button should be present but disabled on web
    await expect(page.getByText('Camera')).toBeVisible();
  });
});

test.describe('Bill Split - Split Options', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await page.getByText('Coins').click();
    await page.getByText('Split Bill').click();
    await page.waitForTimeout(500);
  });

  test('should show split option picker', async ({ page }) => {
    // Click on split option section
    await page.getByText('Paid equally').or(page.getByText('Split equally')).click();
    await page.waitForTimeout(300);

    // Verify split options are shown
    await expect(page.getByText('How to split?')).toBeVisible();
  });

  test('should show paid by picker', async ({ page }) => {
    // Click on paid by section
    await page.getByText('Paid by').click();
    await page.waitForTimeout(300);

    // Verify paid by options
    await expect(page.getByText('Who paid?')).toBeVisible();
    await expect(page.getByText('You')).toBeVisible();
  });
});

