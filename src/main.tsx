import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { initFirebaseRecaptchaConfig } from "./lib/firebase";
import { initOneSignal } from "./lib/onesignal";

initOneSignal();
void initFirebaseRecaptchaConfig();

createRoot(document.getElementById("root")!).render(<App />);
