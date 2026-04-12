/* Keep firebaseConfig in sync with your Firebase web app (same as VITE_FIREBASE_* in .env). */
/* Also acts as the root PWA service worker (one scope `/` — do not add a second SW from PWABuilder). */

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
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
  const options = {
    body,
    icon,
    data: payload.data || {},
  };
  return self.registration.showNotification(title, options);
});
