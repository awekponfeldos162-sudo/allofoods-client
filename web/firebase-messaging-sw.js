// Service Worker Firebase pour l'app client allofoods (Flutter Web).
// Nécessaire pour getToken() FCM et les notifications en arrière-plan sur web.

importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// ⚠️  Remplacer ces valeurs par celles de votre projet Firebase
// Firebase console → Paramètres du projet → Vos applications → Config web
firebase.initializeApp({
  apiKey: "VOTRE_FIREBASE_API_KEY",
  authDomain: "VOTRE_PROJECT_ID.firebaseapp.com",
  projectId: "VOTRE_PROJECT_ID",
  storageBucket: "VOTRE_PROJECT_ID.firebasestorage.app",
  messagingSenderId: "VOTRE_SENDER_ID",
  appId: "VOTRE_APP_ID",
});

const messaging = firebase.messaging();

// Afficher les notifications quand l'app web est en arrière-plan / fermée
messaging.onBackgroundMessage((payload) => {
  console.log("[SW allofoods] Message reçu en arrière-plan:", payload);

  const title = payload.notification?.title
    || payload.data?.title
    || "allofoods";
  const body = payload.notification?.body
    || payload.data?.body
    || "";
  const icon = "/icons/Icon-192.png";

  if (body) {
    self.registration.showNotification(title, { body, icon });
  }
});
