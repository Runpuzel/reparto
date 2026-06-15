// Firebase Cloud Messaging service worker (web push).
// Fill in your Firebase web config below, then push will work on the web build.
// This file must live at the web root and be named exactly this.

importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js",
);

// TODO: replace with your Firebase web app config.
firebase.initializeApp({
  apiKey: "YOUR_WEB_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  self.registration.showNotification(title || "Reparto", {
    body: body || "",
    icon: "/icons/Icon-192.png",
  });
});
