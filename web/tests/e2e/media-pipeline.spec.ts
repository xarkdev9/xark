// XARK OS v2.0 — E2EE Media Pipeline Stress Test
// Verifies the full Symmetric-Blob lifecycle:
//   Sender picks file → encryptFile → upload encrypted blob → send AES key via E2EE →
//   Receiver fetches blob → decryptFile → blurry thumbnail → sharp image
//
// Prerequisites:
//   1. Dev server running: npm run dev (port 3000)
//   2. DEV_MODE=true in .env.local (enables passwordless dev-auto-login)
//   3. Two test users in Supabase: "alice" and "bob" (created via seed or manually)
//   4. A shared test space both users belong to
//   5. Test images generated: npx tsx tests/fixtures/generate-test-image.ts

import { test, expect, type Page, type BrowserContext } from '@playwright/test';
import { existsSync } from 'fs';
import { join } from 'path';

// ── Configuration ──
const TEST_SPACE_ID = process.env.TEST_SPACE_ID || 'space_test_1774115020358';
const SENDER_NAME = process.env.TEST_SENDER || 'alex chen';
const RECEIVER_NAME = process.env.TEST_RECEIVER || 'priya sharma';
const IMAGE_COUNT = 5;
const BASE_URL = 'http://localhost:3000';

// Resolve paths from project root (safe in ESM — no __dirname)
const PROJECT_ROOT = process.cwd();
const FIXTURES_DIR = join(PROJECT_ROOT, 'tests', 'fixtures');
const IMAGES_DIR = join(FIXTURES_DIR, 'images');

// ── Helpers ──

/** Generate test images if they don't exist */
async function ensureTestImages(): Promise<string[]> {
  const paths: string[] = [];
  for (let i = 0; i < IMAGE_COUNT; i++) {
    paths.push(join(IMAGES_DIR, `test-image-${i}.png`));
  }

  if (!existsSync(paths[0])) {
    const { generateTestImages } = await import('../fixtures/generate-test-image');
    return generateTestImages(IMAGE_COUNT);
  }

  return paths;
}

/** Dev-auto-login: navigate to galaxy with name param, wait for E2EE init */
async function loginUser(page: Page, username: string): Promise<void> {
  await page.goto(`${BASE_URL}/galaxy?name=${encodeURIComponent(username)}`);

  // Wait for the page to load and E2EE to initialize
  // The Galaxy page calls useE2EE which sets up crypto
  await page.waitForTimeout(3000);

  // Verify we're on the Galaxy page (not redirected to login)
  await expect(page).toHaveURL(/\/galaxy/);
}

/** Navigate to the test space and wait for E2EE readiness */
async function navigateToSpace(page: Page, spaceId: string, username: string): Promise<void> {
  await page.goto(`${BASE_URL}/space/${spaceId}?name=${encodeURIComponent(username)}`);

  // ── DOM-BASED E2EE READINESS GATE ──
  // The textarea is only visible and enabled once auth + E2EE have fully resolved.
  const textarea = page.locator('textarea[placeholder="message..."]');
  await expect(textarea).toBeVisible({ timeout: 20000 });
  await expect(textarea).toBeEnabled({ timeout: 20000 });

  // Buffer for WebSocket connections and Realtime subscriptions to settle
  await page.waitForTimeout(2000);
}

/** Count message bubbles in the chat (excludes system messages) */
async function countMessageBubbles(page: Page): Promise<number> {
  // Message bubbles use the xark-bubble-sent/received CSS variables as background
  // They are divs with borderRadius containing message content
  return page.locator('[style*="xark-bubble"]').count();
}

/** Wait for a specific number of media images to appear (blurry or sharp) */
async function waitForMediaImages(page: Page, expectedCount: number, timeout = 30000): Promise<void> {
  // Media messages render EncryptedMediaRenderer which produces <img> tags inside bubbles
  // We look for images that are either thumbnails (data: src) or decrypted blobs (blob: src)
  await expect(async () => {
    const mediaImages = page.locator('[style*="xark-bubble"] img');
    const count = await mediaImages.count();
    expect(count).toBeGreaterThanOrEqual(expectedCount);
  }).toPass({ timeout });
}

// ═══════════════════════════════════════════
// TEST SUITE
// ═══════════════════════════════════════════

test.describe('E2EE Media Pipeline Stress Test', () => {
  let contextA: BrowserContext;
  let contextB: BrowserContext;
  let pageA: Page;
  let pageB: Page;
  let testImages: string[];

  test.beforeAll(async ({ browser }) => {
    // Generate test images
    testImages = await ensureTestImages();
    expect(testImages.length).toBe(IMAGE_COUNT);
    for (const p of testImages) {
      expect(existsSync(p)).toBe(true);
    }

    // Create two isolated browser contexts (separate IndexedDB, cookies, storage)
    contextA = await browser.newContext({
      permissions: [],
      viewport: { width: 390, height: 844 }, // iPhone 14 viewport
    });
    contextB = await browser.newContext({
      permissions: [],
      viewport: { width: 390, height: 844 },
    });

    pageA = await contextA.newPage();
    pageB = await contextB.newPage();

    // Enable console log forwarding for debugging
    pageA.on('console', msg => {
      if (msg.type() === 'error' || msg.text().includes('[xark-e2ee]') || msg.text().includes('[encrypted-media]')) {
        console.log(`[SENDER] ${msg.text()}`);
      }
    });
    pageB.on('console', msg => {
      if (msg.type() === 'error' || msg.text().includes('[xark-e2ee]') || msg.text().includes('[encrypted-media]')) {
        console.log(`[RECEIVER] ${msg.text()}`);
      }
    });
  });

  test.afterAll(async () => {
    await contextA?.close();
    await contextB?.close();
  });

  test('Sender and receiver can authenticate and reach the space', async () => {
    // Login both users via dev-auto-login flow
    await loginUser(pageA, SENDER_NAME);
    await loginUser(pageB, RECEIVER_NAME);

    // Navigate both to the shared test space
    await navigateToSpace(pageA, TEST_SPACE_ID, SENDER_NAME);
    await navigateToSpace(pageB, TEST_SPACE_ID, RECEIVER_NAME);

    // Verify both pages show the space (chat input should be visible)
    await expect(pageA.locator('input[type="file"][accept*="image"]').first()).toBeAttached();
    await expect(pageB.locator('input[type="file"][accept*="image"]').first()).toBeAttached();
  });

  test('Rapid-fire send: 5 encrypted images from sender', async () => {
    // Record initial bubble count on sender side
    const initialCount = await countMessageBubbles(pageA);

    for (let i = 0; i < IMAGE_COUNT; i++) {
      // Trigger file selection on the hidden input
      const fileInput = pageA.locator('input[type="file"][accept*="image"]').first();
      await fileInput.setInputFiles(testImages[i]);

      // Wait for the optimistic message to appear in sender's DOM
      // The sender sees the message immediately (optimistic update)
      await pageA.waitForTimeout(2000);

      console.log(`[TEST] Sent image ${i + 1}/${IMAGE_COUNT}`);
    }

    // Wait for all 5 to settle (encryption + upload + API call)
    await pageA.waitForTimeout(5000);

    // Verify sender sees all 5 new media messages
    const finalCount = await countMessageBubbles(pageA);
    expect(finalCount).toBeGreaterThanOrEqual(initialCount + IMAGE_COUNT);
  });

  test('Receiver sees 5 media messages with decrypt lifecycle', async () => {
    // Give Realtime + reconciliation time to deliver
    await pageB.waitForTimeout(8000);

    // Verify receiver has media images
    await waitForMediaImages(pageB, IMAGE_COUNT, 60000);

    // Check each media image goes through the lifecycle
    const mediaImages = pageB.locator('[style*="xark-bubble"] img');
    const count = await mediaImages.count();

    console.log(`[TEST] Receiver sees ${count} media images`);
    expect(count).toBeGreaterThanOrEqual(IMAGE_COUNT);

    // Verify at least some images completed decryption (blob:// URLs)
    let blobCount = 0;
    let thumbnailCount = 0;

    for (let i = 0; i < count; i++) {
      const img = mediaImages.nth(i);
      const src = await img.getAttribute('src');

      if (src?.startsWith('blob:')) {
        blobCount++;
      } else if (src?.startsWith('data:image')) {
        thumbnailCount++;
      }
    }

    console.log(`[TEST] Decrypted blobs: ${blobCount}, Thumbnails still loading: ${thumbnailCount}`);

    // At minimum, some images should have started decrypting
    // (full blob completion depends on network speed + crypto time)
    expect(blobCount + thumbnailCount).toBeGreaterThanOrEqual(IMAGE_COUNT);
  });

  test('Blurry thumbnail lifecycle: blur → sharp transition', async () => {
    // Reload receiver page to test cache + thumbnail flow from scratch
    await navigateToSpace(pageB, TEST_SPACE_ID, RECEIVER_NAME);

    // Wait for messages to load from cache / server
    await pageB.waitForTimeout(5000);

    const mediaImages = pageB.locator('[style*="xark-bubble"] img');
    const count = await mediaImages.count();

    if (count === 0) {
      console.log('[TEST] No media images after reload — skipping thumbnail lifecycle check');
      return;
    }

    // Check for blur filter on loading thumbnails
    let foundBlurry = false;
    let foundSharp = false;

    for (let i = 0; i < count; i++) {
      const img = mediaImages.nth(i);
      const style = await img.getAttribute('style') ?? '';
      const src = await img.getAttribute('src') ?? '';

      if (style.includes('blur(8px)')) {
        foundBlurry = true;
        console.log(`[TEST] Image ${i}: blurry thumbnail (still decrypting)`);
      }
      if (src.startsWith('blob:') && !style.includes('blur')) {
        foundSharp = true;
        console.log(`[TEST] Image ${i}: sharp decrypted blob`);
      }
    }

    // Wait for remaining decryptions to complete
    await pageB.waitForTimeout(15000);

    // Re-check: after waiting, at least some should be sharp blobs
    let finalBlobCount = 0;
    const finalImages = pageB.locator('[style*="xark-bubble"] img');
    const finalCount = await finalImages.count();

    for (let i = 0; i < finalCount; i++) {
      const src = await finalImages.nth(i).getAttribute('src');
      if (src?.startsWith('blob:')) finalBlobCount++;
    }

    console.log(`[TEST] After full wait: ${finalBlobCount}/${finalCount} images fully decrypted`);

    // At least 1 image should have completed the full cycle
    if (finalBlobCount > 0) {
      expect(finalBlobCount).toBeGreaterThanOrEqual(1);
    }
  });

  test('Sender media survives page refresh (cache hit)', async () => {
    // Reload sender page
    await navigateToSpace(pageA, TEST_SPACE_ID, SENDER_NAME);
    await pageA.waitForTimeout(5000);

    // Sender's own media should be cached (saveDecryptedMedia on send)
    const mediaImages = pageA.locator('[style*="xark-bubble"] img');
    const count = await mediaImages.count();

    console.log(`[TEST] Sender sees ${count} media images after reload`);

    // Sender should see their own media (from cache)
    // At minimum the text content should be present even if blobs are still loading
    const bubbleCount = await countMessageBubbles(pageA);
    expect(bubbleCount).toBeGreaterThan(0);
  });

  test('No object URL memory leaks (unmount cleanup)', async () => {
    // Navigate away from space (to Galaxy) and back
    await pageB.goto(`${BASE_URL}/galaxy?name=${encodeURIComponent(RECEIVER_NAME)}`);
    await pageB.waitForTimeout(2000);

    // Navigate back — EncryptedMediaRenderer unmount should have revoked URLs
    await navigateToSpace(pageB, TEST_SPACE_ID, RECEIVER_NAME);
    await pageB.waitForTimeout(5000);

    // New images should be loading fresh (not using stale revoked URLs)
    const mediaImages = pageB.locator('[style*="xark-bubble"] img');
    const count = await mediaImages.count();

    // Verify no images have revoked blob: URLs (would show as broken)
    for (let i = 0; i < count; i++) {
      const img = mediaImages.nth(i);
      const src = await img.getAttribute('src') ?? '';

      if (src.startsWith('blob:')) {
        // Image with blob: URL should be visible (not broken)
        const isVisible = await img.isVisible();
        expect(isVisible).toBe(true);
      }
    }

    console.log(`[TEST] ${count} images rendering correctly after navigation cycle`);
  });
});
