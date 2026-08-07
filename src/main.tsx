import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

createRoot(document.getElementById("root")!).render(<App />);

/** Run after first paint so Firebase/OneSignal/FCM do not compete with login UI. */
function deferStartupSideEffects(fn: () => void) {
  if (typeof window === "undefined") return;
  const ric = (window as Window & { requestIdleCallback?: (cb: () => void, opts?: { timeout: number }) => number })
    .requestIdleCallback;
  if (typeof ric === "function") {
    ric(fn, { timeout: 2500 });
  } else {
    window.setTimeout(fn, 1);
  }
}

deferStartupSideEffects(() => {
  void import("./lib/pwaServiceWorker").then(({ registerPwaServiceWorker }) => {
    registerPwaServiceWorker();
  });
  void import("./lib/firebase").then(({ injectRecaptchaEnterpriseScript, initFirebaseAnalytics, initFirebaseRecaptchaConfig }) => {
    injectRecaptchaEnterpriseScript();
    void initFirebaseRecaptchaConfig();
    void initFirebaseAnalytics();
  });
  void import("./lib/onesignal").then(({ initOneSignal }) => {
    initOneSignal();
  });
  void import("./lib/fcmWeb").then(({ initFcmForegroundMessaging }) => {
    initFcmForegroundMessaging();
  });
});
