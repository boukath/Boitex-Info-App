// web/firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyDY6a2Rcd5vb1sFsCtvrrZI7sH8kbfQMYU",
  authDomain: "boitexinfo-817cf.firebaseapp.com",
  projectId: "boitexinfo-817cf",
  storageBucket: "boitexinfo-817cf.firebasestorage.app",
  messagingSenderId: "259382800959",
  appId: "1:259382800959:web:9d8d8de948fc568a237e8a",
  measurementId: "G-VJ7EFMERXC"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// 🛑 FORCE BACKGROUND HANDLING
// This event listener handles push events when the app is NOT in the foreground.
// It is the standard Service Worker "push" event, which is more reliable than onBackgroundMessage for system notifications.
self.addEventListener('push', function(event) {
  console.log('[Service Worker] Push Received.');
  console.log(`[Service Worker] Push had this data: "${event.data.text()}"`);

  let payload = event.data.json();

  // Customize notification
  const title = payload.notification?.title || 'Boitex Info Notification';
  const options = {
    body: payload.notification?.body || 'Vous avez un nouveau message.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    requireInteraction: true, // ⚠️ Keeps notification on screen until clicked
    silent: false,
    vibrate: [200, 100, 200]
  };

  const notificationPromise = self.registration.showNotification(title, options);
  event.waitUntil(notificationPromise);
});

// Handle Notification Click
self.addEventListener('notificationclick', function(event) {
  console.log('[Service Worker] Notification click received.');
  event.notification.close();

  const urlToOpen = self.location.origin;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
      // Focus existing tab if open
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url.indexOf(urlToOpen) !== -1 && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new tab if none open
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});