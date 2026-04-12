/**
 * Registers the site-wide service worker on startup (production only).
 * FCM uses the same file later via getToken(..., { serviceWorkerRegistration });
 * registering early satisfies PWA audits (e.g. PWABuilder) that only see the first load.
 */
export function registerPwaServiceWorker(): void {
  if (typeof window === "undefined" || !("serviceWorker" in navigator)) return;
  if (!import.meta.env.PROD) return;

  void navigator.serviceWorker
    .register("/firebase-messaging-sw.js", { type: "classic", scope: "/" })
    .catch(() => {
      /* blocked, unsupported, or offline */
    });
}
