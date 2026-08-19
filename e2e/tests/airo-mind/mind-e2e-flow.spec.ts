import { expect, test } from '@playwright/test';
import {
  openMindRoute,
  tapMindNav,
  waitForScribeShell,
} from '../helpers/mind-browser';
import {
  clearMindSteps,
  hasMindBlockers,
  printMindE2ESummary,
  recordMindStep,
} from '../helpers/mind-e2e-report';

/**
 * Browser analogue of Phase 1.4 (macOS manual checklist).
 *
 * Web can prove shell routes, assistant catalog, and navigation chrome.
 * Vault Devices, Notes persist, Runtime Console replayFrom, and ECAPA speaker
 * enroll require macOS native — recorded as native-only, not failures.
 *
 * Run via:
 *   scripts/validate_airo_mind_browser.sh mind-e2e-flow.spec.ts
 */

test.describe('Airo Mind Phase 1 browser flow @e2e', () => {
  test.beforeAll(() => {
    clearMindSteps();
    recordMindStep({
      id: 'native-devices',
      phase: '1B',
      label: 'Devices / fingerprints (#1592)',
      status: 'native-only',
      error: 'Rust vault UI — run app/tool/run_mind_macos.sh',
    });
    recordMindStep({
      id: 'native-notes',
      phase: '1B',
      label: 'Notes survive restart',
      status: 'native-only',
      error: 'Rust notes log — macOS only',
    });
    recordMindStep({
      id: 'native-replay',
      phase: '1B',
      label: 'Runtime console replayFrom (#1216)',
      status: 'native-only',
      error: 'Surface 13 disabled on web/macOS',
    });
    recordMindStep({
      id: 'native-speaker',
      phase: '1B',
      label: 'Speaker enroll (#504)',
      status: 'native-only',
      error: 'ECAPA ONNX — macOS native',
    });
  });

  test.afterAll(() => {
    printMindE2ESummary();
  });

  test('product title', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    try {
      await expect(page).toHaveTitle(/Airo Mind/i);
      recordMindStep({
        id: 'title',
        phase: '1A',
        label: 'Document title is Airo Mind',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'title',
        phase: '1A',
        label: 'Document title is Airo Mind',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('scribe shell mounts', async ({ page }) => {
    try {
      await openMindRoute(page, '/');
      await waitForScribeShell(page);
      recordMindStep({
        id: 'scribe-mount',
        phase: '1B.A',
        label: 'Scribe home mounts (library or model bootstrap)',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'scribe-mount',
        phase: '1B.A',
        label: 'Scribe home mounts',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('assistant hub and desktop catalog', async ({ page }) => {
    try {
      await openMindRoute(page, '/mind');
      await expect(page.getByText('Airo AI Lab')).toBeVisible({
        timeout: 60000,
      });
      await expect(page.getByText('Audio Scribe')).toBeVisible();
      await expect(page.getByText('Prompt Lab')).toBeVisible();
      await expect(page.getByText('Ask Image')).toHaveCount(0);
      await expect(page.getByText('Mobile Actions & Tiny Garden')).toHaveCount(
        0,
      );
      recordMindStep({
        id: 'assistant-hub',
        phase: '1B',
        label: 'Assistant hub + desktop skill filter',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'assistant-hub',
        phase: '1B',
        label: 'Assistant hub + desktop skill filter',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('audio scribe consent surface', async ({ page }) => {
    try {
      await openMindRoute(page, '/mind/audio-scribe');
      await expect(
        page.getByText(/consent|jurisdiction|recording/i).first(),
      ).toBeVisible({ timeout: 90000 });
      recordMindStep({
        id: 'audio-scribe-ui',
        phase: '1B.A',
        label: 'Audio Scribe consent UI loads',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'audio-scribe-ui',
        phase: '1B.A',
        label: 'Audio Scribe consent UI loads',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('chat prompt chips omit mobile-only skills', async ({ page }) => {
    try {
      await openMindRoute(page, '/mind/chat');
      await expect(
        page.getByRole('checkbox', { name: 'Diet Plan' }),
      ).toBeVisible({ timeout: 90000 });
      await expect(
        page.getByRole('checkbox', { name: 'Audio Scribe' }),
      ).toBeVisible();
      await expect(
        page.getByRole('checkbox', { name: 'Mobile Actions' }),
      ).toHaveCount(0);
      recordMindStep({
        id: 'chat-chips',
        phase: '1B',
        label: 'Chat chips respect Mind desktop policy',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'chat-chips',
        phase: '1B',
        label: 'Chat chips respect Mind desktop policy',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('models route exposes on-device catalog', async ({ page }) => {
    try {
      await openMindRoute(page, '/models');
      await expect(page.getByText('On-device models')).toBeVisible({
        timeout: 60000,
      });
      await expect(page.getByText(/Gemma|Qwen|Download/i).first()).toBeVisible({
        timeout: 60000,
      });
      recordMindStep({
        id: 'models-catalog',
        phase: '1B',
        label: 'Models catalog route',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'models-catalog',
        phase: '1B',
        label: 'Models catalog route',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('shell bottom navigation', async ({ page }) => {
    try {
      await openMindRoute(page, '/mind');
      for (const label of ['Scribe', 'Assistant', 'Models', 'Wellbeing']) {
        await tapMindNav(page, label);
      }
      await expect(
        page.getByRole('heading', { name: 'Wellbeing' }),
      ).toBeVisible({ timeout: 60000 });
      recordMindStep({
        id: 'shell-nav',
        phase: '1B',
        label: 'Bottom nav across four destinations',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'shell-nav',
        phase: '1B',
        label: 'Bottom nav across four destinations',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('wellbeing route', async ({ page }) => {
    try {
      await openMindRoute(page, '/wellbeing');
      await expect(
        page.getByRole('heading', { name: 'Wellbeing' }),
      ).toBeVisible({ timeout: 60000 });
      recordMindStep({
        id: 'wellbeing',
        phase: '1B',
        label: 'Wellbeing surface',
        status: 'pass',
      });
    } catch (error) {
      recordMindStep({
        id: 'wellbeing',
        phase: '1B',
        label: 'Wellbeing surface',
        status: 'fail',
        error: String(error),
      });
      throw error;
    }
  });

  test('E2E summary gate @e2e', () => {
    printMindE2ESummary();
    expect(hasMindBlockers(), 'See Mind browser E2E summary in logs').toBe(
      false,
    );
  });
});
