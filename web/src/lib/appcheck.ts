import { getApps } from 'firebase/app';
import { initializeAppCheck, ReCaptchaV3Provider, getToken } from 'firebase/app-check';

let appCheckInstance: any = null;

export function initAppCheck() {
  if (appCheckInstance) return;
  if (typeof window === 'undefined') return; // SSR guard

  const app = getApps()[0];
  if (!app) return;

  const siteKey = process.env.NEXT_PUBLIC_RECAPTCHA_V3_SITE_KEY;
  if (!siteKey) {
    console.warn('[AppCheck] NEXT_PUBLIC_RECAPTCHA_V3_SITE_KEY not set — skipping');
    return;
  }

  appCheckInstance = initializeAppCheck(app, {
    provider: new ReCaptchaV3Provider(siteKey),
    isTokenAutoRefreshEnabled: true,
  });
}

export async function getAppCheckToken(): Promise<string | null> {
  if (!appCheckInstance) return null;
  try {
    const result = await getToken(appCheckInstance, false);
    return result.token;
  } catch {
    return null;
  }
}
