// web/firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// Initialize the Firebase app in the service worker by passing in the
// messagingOptions.
firebase.initializeApp({
  apiKey: "AIzaSyDY6a2Rcd5vb1sFsCtvrrZI7sH8kbfQMYU",
  authDomain: "boitexinfo-817cf.firebaseapp.com",
  projectId: "boitexinfo-817cf",
  storageBucket: "boitexinfo-817cf.firebasestorage.app",
  messagingSenderId: "259382800959",
  appId: "1:259382800959:web:9d8d8de948fc568a237e8a",
  measurementId: "G-VJ7EFMERXC"
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png', // Ensure this matches the icon path in your web/icons folder
    // You can add more options here like 'click_action' to open a specific URL
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});