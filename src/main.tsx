import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { injectRecaptchaEnterpriseScript, initFirebaseAnalytics, initFirebaseRecaptchaConfig } from "./lib/firebase";
import { initFcmForegroundMessaging } from "./lib/fcmWeb";
import { registerPwaServiceWorker } from "./lib/pwaServiceWorker";
import { initOneSignal } from "./lib/onesignal";

registerPwaServiceWorker();
injectRecaptchaEnterpriseScript();
initOneSignal();
void initFirebaseRecaptchaConfig();
void initFirebaseAnalytics();
initFcmForegroundMessaging();

createRoot(document.getElementById("root")!).render(<App />);
