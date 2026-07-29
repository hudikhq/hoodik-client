#!/usr/bin/env node
/*
 * Drives the hoodik web registration form via Playwright headless Chromium
 * to seed the ephemeral hoodik server (the one docker-hoodik-up.sh boots) with
 * the deterministic E2E user that integration_test/e2e/test_env.dart defaults
 * to. Mirrors the flow in hoodik/web/e2e/helpers/auth.ts:createUser — uses
 * the real WASM keypair generation in the Vue app, not a faked PEM via API.
 *
 * Idempotent: a "user already exists" page is treated as success, since the
 * server's SQLite is not wiped between Patrol runs within a single just session.
 *
 * Env vars:
 *   HOODIK_E2E_URL       defaults to http://127.0.0.1:5443 (must match docker-compose.e2e.yml)
 *   HOODIK_E2E_EMAIL     defaults to e2e@hoodik.local
 *   HOODIK_E2E_PASSWORD  defaults to e2e-user-password-1234
 *   HEADED               set to "1" to watch the browser (debugging only)
 */

const { chromium } = require('@playwright/test');

const BASE_URL = process.env.HOODIK_E2E_URL || 'http://127.0.0.1:5443';
const EMAIL = process.env.HOODIK_E2E_EMAIL || 'e2e@hoodik.local';
const PASSWORD = process.env.HOODIK_E2E_PASSWORD || 'e2e-user-password-1234';
const HEADLESS = process.env.HEADED !== '1';

function log(msg) {
  process.stdout.write(`[bootstrap] ${msg}\n`);
}

async function main() {
  log(`registering ${EMAIL} on ${BASE_URL}`);
  const browser = await chromium.launch({ headless: HEADLESS });
  const context = await browser.newContext({
    baseURL: BASE_URL,
    // Self-signed cert tolerance — docker-compose.e2e.yml runs SSL_DISABLED=true
    // but leaving this on means the script also works against TLS-enabled instances.
    ignoreHTTPSErrors: true,
  });
  const page = await context.newPage();

  try {
    await page.goto('/auth/login', { waitUntil: 'load' });
    if (await page.locator('#email').isVisible({ timeout: 5000 }).catch(() => false)) {
      await page.locator('#email').fill(EMAIL);
      await page.locator('#password').fill(PASSWORD);
      await page.getByRole('button', { name: 'Login' }).click();
      const ok = await page.waitForURL('**/', { timeout: 5000, waitUntil: 'load' }).then(() => true).catch(() => false);
      if (ok) {
        log('user already exists and login succeeded — nothing to do');
        return;
      }
    }

    await page.goto('/auth/register', { waitUntil: 'load' });
    await page.locator('#email').fill(EMAIL);
    await page.locator('#password').fill(PASSWORD);
    await page.locator('#confirm_password').fill(PASSWORD);
    await page.getByRole('button', { name: 'Next' }).click();

    await page.waitForURL('**/register/key', { timeout: 30_000 });
    await page.locator('#i_have_stored_my_private_key').check();
    await page.getByRole('button', { name: 'Next' }).click();

    await page.waitForURL('**/register/two-factor', { timeout: 10_000 });
    await page.getByRole('button', { name: 'Skip' }).click();

    await page.waitForURL('**/', { timeout: 10_000, waitUntil: 'load' });
    log('registration succeeded');
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((err) => {
  process.stderr.write(`[bootstrap] FAIL: ${err && err.message ? err.message : err}\n`);
  process.exit(1);
});
