// Firebase Cloud Messaging service worker (web push).
// Fill in your Firebase web config below, then push will work on the web build.
// This file must live at the web root and be named exactly this.

importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyDX9NOzmiWl4dFeui7pB6Bo00S5eG1QBig",
  authDomain: "reparto-b5957.firebaseapp.com",
  projectId: "reparto-b5957",
  storageBucket: "reparto-b5957.firebasestorage.app",
  messagingSenderId: "462208558450",
  appId: "1:462208558450:web:10520cf436d08ad8c2e9eb",
  measurementId: "G-4GL8XDLW07",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  self.registration.showNotification(title || "UjustBUY", {
    body: body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: { url: payload?.data?.route || "/notifications" },
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data?.url || "/notifications"));
});
