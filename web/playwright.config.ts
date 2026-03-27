import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 120_000, // 2 min per test (media stress test is heavy)
  expect: { timeout: 30_000 },
  fullyParallel: false, // E2E media tests need sequential execution
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
  // Dev server must be running — don't auto-start (E2EE needs real Supabase)
});
