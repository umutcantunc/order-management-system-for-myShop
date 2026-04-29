// Firebase Cloud Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Firebase yapılandırması
const firebaseConfig = {
  apiKey: "AIzaSyA4FbmQOmWY8TlmwmvXJEwe7tFOsDukBgw",
  authDomain: "tuncnurbranda-a93a5.firebaseapp.com",
  projectId: "tuncnurbranda-a93a5",
  storageBucket: "tuncnurbranda-a93a5.firebasestorage.app",
  messagingSenderId: "590959884913",
  appId: "1:590959884913:web:c7a984a8b2389947a139d0",
  measurementId: "G-VDHDS02E74"
};

// Firebase'i başlat
firebase.initializeApp(firebaseConfig);

// Messaging instance'ı al
const messaging = firebase.messaging();

// Background bildirimleri dinle
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background bildirim alındı:', payload);
  
  const notificationTitle = payload.notification?.title || 'Tunç Nur Branda';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.messageId,
    requireInteraction: true,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Bildirime tıklandığında
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Bildirime tıklandı:', event);
  event.notification.close();
  
  // Uygulamayı aç
  event.waitUntil(
    clients.openWindow('/')
  );
});
