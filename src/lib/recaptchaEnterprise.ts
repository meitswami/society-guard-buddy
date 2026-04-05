/**
 * reCAPTCHA Enterprise (score-based) for Firebase Phone Auth.
 * Load https://www.google.com/recaptcha/enterprise.js?render=<siteKey> then
 * grecaptcha.enterprise.execute(siteKey, { action }) — same flow as Google's docs.
 */

declare global {
  interface Window {
    grecaptcha?: {
      enterprise: {
        ready: (callback: () => void) => void;
        execute: (siteKey: string, options: { action: string }) => Promise<string>;
      };
    };
  }
}

const SCRIPT_ID = 'recaptcha-enterprise-sdk';

function scriptAlreadyLoadingOrLoaded(siteKey: string): boolean {
  const scripts = document.querySelectorAll<HTMLScriptElement>('script[src*="recaptcha/enterprise.js"]');
  for (const s of scripts) {
    if (s.src.includes(encodeURIComponent(siteKey)) || s.src.includes(siteKey)) return true;
  }
  return !!document.getElementById(SCRIPT_ID);
}

let loadPromise: Promise<void> | null = null;

export function getRecaptchaEnterpriseSiteKey(): string | undefined {
  const k = import.meta.env.VITE_RECAPTCHA_ENTERPRISE_SITE_KEY;
  return typeof k === 'string' && k.trim() !== '' ? k.trim() : undefined;
}

export function isRecaptchaEnterpriseConfigured(): boolean {
  return Boolean(getRecaptchaEnterpriseSiteKey());
}

function waitForEnterpriseReady(timeoutMs = 20000): Promise<void> {
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const run = () => {
      const g = window.grecaptcha?.enterprise;
      if (g?.ready) {
        g.ready(() => resolve());
        return;
      }
      if (Date.now() - t0 > timeoutMs) {
        reject(new Error('reCAPTCHA Enterprise API did not become ready in time.'));
        return;
      }
      requestAnimationFrame(run);
    };
    run();
  });
}

/**
 * Ensures enterprise.js is loaded (injects script if missing).
 */
export function loadRecaptchaEnterpriseScript(siteKey: string): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();

  if (window.grecaptcha?.enterprise?.execute) {
    return waitForEnterpriseReady();
  }

  if (loadPromise) return loadPromise;

  loadPromise = new Promise((resolve, reject) => {
    if (scriptAlreadyLoadingOrLoaded(siteKey)) {
      waitForEnterpriseReady().then(resolve).catch(reject);
      return;
    }

    const s = document.createElement('script');
    s.id = SCRIPT_ID;
    s.src = `https://www.google.com/recaptcha/enterprise.js?render=${encodeURIComponent(siteKey)}`;
    s.async = true;
    s.defer = true;
    s.onload = () => {
      waitForEnterpriseReady().then(resolve).catch(reject);
    };
    s.onerror = () => {
      loadPromise = null;
      reject(new Error('Failed to load reCAPTCHA Enterprise script.'));
    };
    document.head.appendChild(s);
  });

  return loadPromise;
}

export async function executeRecaptchaEnterprise(siteKey: string, action: string): Promise<string> {
  await loadRecaptchaEnterpriseScript(siteKey);
  await waitForEnterpriseReady();
  const exec = window.grecaptcha?.enterprise?.execute;
  if (!exec) throw new Error('grecaptcha.enterprise.execute is not available.');
  return exec(siteKey, { action });
}
