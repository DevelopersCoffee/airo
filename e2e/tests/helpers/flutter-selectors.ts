import { Page, Locator } from '@playwright/test';

/**
 * Helper functions for selecting Flutter Web elements
 * Flutter with HTML renderer exposes widgets via flt-semantics elements
 */

// Login Screen Test IDs (must match Dart LoginTestIds)
export const LoginTestIds = {
  screen: 'login-screen',
  usernameInput: 'login-username-input',
  passwordInput: 'login-password-input',
  signInButton: 'login-sign-in-button',
  googleSignInButton: 'login-google-sign-in-button',
  registerLink: 'login-register-link',
  demoCredentialsButton: 'login-demo-credentials-button',
  errorMessage: 'login-error-message',
} as const;

// Bill Split Screen Test IDs (must match Dart BillSplitTestIds)
export const BillSplitTestIds = {
  screen: 'bill-split-screen',
  descriptionInput: 'bill-description-input',
  amountInput: 'bill-amount-input',
  saveButton: 'bill-save-button',
  newButton: 'bill-new-button',
  participantsSection: 'bill-participants-section',
  paidBySection: 'bill-paid-by-section',
  splitOptionSection: 'bill-split-option-section',
  splitByItemsButton: 'bill-split-by-items-button',
  shareButton: 'bill-share-button',
  copyButton: 'bill-copy-button',
  resultView: 'bill-result-view',
} as const;

// Itemized Split Screen Test IDs (must match Dart ItemizedSplitTestIds)
export const ItemizedSplitTestIds = {
  screen: 'itemized-split-screen',
  cameraButton: 'itemized-camera-button',
  galleryButton: 'itemized-gallery-button',
  loadingIndicator: 'itemized-loading-indicator',
  vendorHeader: 'itemized-vendor-header',
  itemsList: 'itemized-items-list',
  itemCard: 'itemized-item-card',
  participantChip: 'itemized-participant-chip',
  summaryFooter: 'itemized-summary-footer',
  confirmButton: 'itemized-confirm-button',
  quickAssignButton: 'itemized-quick-assign-button',
  itemCardId: (itemId: string) => `item-${itemId}`,
  participantChipId: (participantId: string) => `chip-${participantId}`,
} as const;

/**
 * Get a Flutter widget by its Key value
 * Flutter HTML renderer uses data-flt-key attribute for Keys
 */
export function getByKey(page: Page, key: string): Locator {
  // Flutter HTML renderer exposes Keys as flt-semantics-value or data attributes
  return page.locator(`[flt-semantics-value="${key}"], [data-flt-key="${key}"], flt-semantics[label="${key}"]`);
}

/**
 * Get element by text content (for buttons, labels, etc.)
 */
export function getByText(page: Page, text: string): Locator {
  return page.getByText(text);
}

/**
 * Get input field by placeholder text
 */
export function getByPlaceholder(page: Page, placeholder: string): Locator {
  return page.getByPlaceholder(placeholder);
}

/**
 * Wait for Flutter to be fully loaded
 */
export async function waitForFlutterReady(page: Page, timeout = 30000): Promise<void> {
  // Wait for Flutter bootstrap to complete
  await page.waitForFunction(
    () => {
      // Check if Flutter engine is initialized
      const flutter = (window as any).flutter;
      return flutter && flutter.loader && flutter.loader._scriptLoaded;
    },
    { timeout }
  );
  
  // Additional wait for rendering
  await page.waitForTimeout(1000);
}

/**
 * Navigate to a specific route in Flutter app
 */
export async function navigateTo(page: Page, route: string): Promise<void> {
  // Flutter uses hash-based routing by default
  await page.goto(`/#${route}`);
  await page.waitForTimeout(500);
}

/**
 * Click on a Flutter button/widget
 */
export async function clickWidget(page: Page, identifier: string): Promise<void> {
  const element = getByText(page, identifier).or(getByKey(page, identifier));
  await element.click();
}

/**
 * Fill a Flutter text field
 */
export async function fillTextField(page: Page, placeholder: string, value: string): Promise<void> {
  const field = getByPlaceholder(page, placeholder);
  await field.click();
  await field.fill(value);
}

/**
 * Check if a widget is visible
 */
export async function isWidgetVisible(page: Page, identifier: string): Promise<boolean> {
  const element = getByText(page, identifier).or(getByKey(page, identifier));
  return element.isVisible();
}

