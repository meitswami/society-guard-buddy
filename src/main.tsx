import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { injectRecaptchaEnterpriseScript, initFirebaseAnalytics, initFirebaseRecaptchaConfig } from "./lib/firebase";
import { initFcmForegroundMessaging } from "./lib/fcmWeb";
import { initOneSignal } from "./lib/onesignal";

injectRecaptchaEnterpriseScript();
initOneSignal();
void initFirebaseRecaptchaConfig();
void initFirebaseAnalytics();
initFcmForegroundMessaging();

createRoot(document.getElementById("root")!).render(<App />);
