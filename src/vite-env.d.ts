/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
  /** Same as URL/key above; supported for Vercel / Next-style env names (see vite.config envPrefix). */
  readonly NEXT_PUBLIC_SUPABASE_URL?: string;
  readonly NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string;
  readonly VITE_FIREBASE_API_KEY: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN: string;
  readonly VITE_FIREBASE_PROJECT_ID: string;
  readonly VITE_FIREBASE_STORAGE_BUCKET: string;
  readonly VITE_FIREBASE_MESSAGING_SENDER_ID: string;
  readonly VITE_FIREBASE_APP_ID: string;
  readonly VITE_FIREBASE_MEASUREMENT_ID?: string;
  /** Web Push / FCM: Firebase Console → Project settings → Cloud Messaging → Web Push certificates */
  readonly VITE_FIREBASE_VAPID_KEY?: string;
  /** reCAPTCHA Enterprise site key — Google Cloud reCAPTCHA; must match Firebase Auth / App Check linkage */
  readonly VITE_RECAPTCHA_ENTERPRISE_SITE_KEY?: string;
  /** If true, block OTP when server-side recaptcha-assessment has transient errors. */
  readonly VITE_RECAPTCHA_ASSESSMENT_STRICT?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
