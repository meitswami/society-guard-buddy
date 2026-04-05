import { initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, initializeRecaptchaConfig, type Auth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY as string | undefined,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN as string | undefined,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID as string | undefined,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET as string | undefined,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID as string | undefined,
  appId: import.meta.env.VITE_FIREBASE_APP_ID as string | undefined,
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID as string | undefined,
};

export function isFirebaseConfigured(): boolean {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.authDomain &&
      firebaseConfig.projectId &&
      firebaseConfig.appId
  );
}

let app: FirebaseApp | null = null;

export function getFirebaseApp(): FirebaseApp {
  if (!isFirebaseConfigured()) {
    throw new Error('Firebase is not configured (missing VITE_FIREBASE_* env vars).');
  }
  if (!app) {
    app = initializeApp({
      apiKey: firebaseConfig.apiKey!,
      authDomain: firebaseConfig.authDomain!,
      projectId: firebaseConfig.projectId!,
      storageBucket: firebaseConfig.storageBucket,
      messagingSenderId: firebaseConfig.messagingSenderId,
      appId: firebaseConfig.appId!,
      measurementId: firebaseConfig.measurementId,
    });
  }
  return app;
}

export function getFirebaseAuth(): Auth {
  return getAuth(getFirebaseApp());
}

/**
 * Loads reCAPTCHA Enterprise / enforcement config from Firebase for this web app.
 * Call once on startup (and before phone auth) so the SDK uses the site key linked in
 * Google Cloud / Firebase, not a mismatched client-side key.
 */
export async function initFirebaseRecaptchaConfig(): Promise<void> {
  if (!isFirebaseConfigured() || typeof window === 'undefined') return;
  try {
    await initializeRecaptchaConfig(getFirebaseAuth());
  } catch {
    /* SDK retries on first phone auth if this fails */
  }
}
