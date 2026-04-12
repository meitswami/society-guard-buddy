const RECAPTCHA_PHONE_ACTION = 'phone_otp_request';

declare global {
  interface Window {
    grecaptcha?: {
      enterprise?: {
        ready: (cb: () => void) => void;
        execute: (siteKey: string, options: { action: string }) => Promise<string>;
      };
    };
  }
}

/**
 * Runs grecaptcha.enterprise.execute (v3-style token) for server-side CreateAssessment.
 * Requires enterprise.js loaded (see injectRecaptchaEnterpriseScript in firebase.ts).
 */
export async function executeRecaptchaEnterpriseAction(
  action: string = RECAPTCHA_PHONE_ACTION,
): Promise<string | null> {
  if (typeof window === 'undefined') return null;
  const siteKey = import.meta.env.VITE_RECAPTCHA_ENTERPRISE_SITE_KEY?.trim();
  if (!siteKey) return null;

  await new Promise<void>((resolve) => {
    window.grecaptcha?.enterprise?.ready(() => resolve());
  });

  const exec = window.grecaptcha?.enterprise?.execute;
  if (!exec) return null;

  try {
    const token = await exec(siteKey, { action });
    return token || null;
  } catch {
    return null;
  }
}

export { RECAPTCHA_PHONE_ACTION };
