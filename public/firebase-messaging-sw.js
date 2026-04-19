/* Keep firebaseConfig in sync with your Firebase web app (same as VITE_FIREBASE_* in .env). */
/* Also acts as the root PWA service worker (one scope `/` — do not add a second SW from PWABuilder). */

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Do not intercept cross-origin fetches (e.g. Supabase Edge Functions). Handling all URLs
// with respondWith(fetch) can break CORS preflight from the controlled page to *.supabase.co.
self.addEventListener('fetch', (event) => {
  try {
    const url = new URL(event.request.url);
    if (url.origin === self.location.origin) {
      event.respondWith(fetch(event.request));
    }
  } catch {
    /* ignore invalid URL */
  }
});

importScripts('https://www.gstatic.com/firebasejs/12.11.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.11.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDUS7lWHwUcMxtOHFTX-o6zslav7t090d0',
  authDomain: 'kutumbika-5ce7d.firebaseapp.com',
  projectId: 'kutumbika-5ce7d',
  storageBucket: 'kutumbika-5ce7d.firebasestorage.app',
  messagingSenderId: '1056891603634',
  appId: '1:1056891603634:web:0b2aec95e4ad06e29897ab',
  measurementId: 'G-EGBKYGWKMN',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Kutumbika';
  const body = payload.notification?.body || '';
  const icon = payload.notification?.icon || '/favicon.ico';
  const data = payload.data || {};
  const options = {
    body,
    icon,
    data,
    tag: 'kutumbika-alert',
    renotify: true,
    vibrate: [180, 80, 180],
  };
  return self.registration.showNotification(title, options);
});
