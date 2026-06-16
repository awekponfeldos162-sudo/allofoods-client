# Documentation Technique — allofoods Application Client

> **Plateforme** : Flutter (Android / iOS / Web)  
> **Version** : 1.0.0  
> **Dernière mise à jour** : Juin 2026  
> **Équipe** : Développement allofoods — Cotonou, Bénin

---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture technique](#2-architecture-technique)
3. [Stack technique et dépendances](#3-stack-technique-et-dépendances)
4. [Structure du projet](#4-structure-du-projet)
5. [Pages et fonctionnalités](#5-pages-et-fonctionnalités)
6. [Gestion d'état — Providers](#6-gestion-détat--providers)
7. [Modèles de données](#7-modèles-de-données)
8. [Services](#8-services)
9. [Backend Firebase](#9-backend-firebase)
10. [Paiement Mobile Money — FedaPay](#10-paiement-mobile-money--fedapay)
11. [Géolocalisation et tracking en temps réel](#11-géolocalisation-et-tracking-en-temps-réel)
12. [Notifications push — FCM](#12-notifications-push--fcm)
13. [Internationalisation](#13-internationalisation)
14. [Configuration et variables d'environnement](#14-configuration-et-variables-denvironnement)
15. [Guide de démarrage développeur](#15-guide-de-démarrage-développeur)
16. [Flux utilisateur complet](#16-flux-utilisateur-complet)
17. [Support utilisateurs internes — Problèmes courants](#17-support-utilisateurs-internes--problèmes-courants)

---

## 1. Vue d'ensemble

**allofoods** est une application mobile de livraison de repas à domicile ciblant le marché béninois (Cotonou et environs). Elle permet aux utilisateurs de :

- Parcourir les restaurants partenaires
- Commander des plats et les payer en Mobile Money (MTN, Moov, Celtis)
- Suivre leur commande en temps réel sur une carte Google Maps
- Communiquer avec le livreur par chat, WhatsApp ou appel téléphonique
- Gérer leur profil, adresses favorites et historique de commandes

L'application est connectée en temps réel à Firebase (Firestore, Auth, Messaging) et traite les paiements via l'API FedaPay avec des Cloud Functions sécurisées.

---

## 2. Architecture technique

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION CLIENT (Flutter)              │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Pages   │  │Providers │  │ Services │  │  Models  │   │
│  │  (UI)    │◄─│ (State)  │◄─│  (Logic) │◄─│  (Data)  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│        │             │              │                        │
└────────┼─────────────┼──────────────┼────────────────────────┘
         │             │              │
         ▼             ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND / APIs                           │
│                                                             │
│  Firebase Auth    Firestore DB    Firebase Storage          │
│  Firebase FCM     Cloud Functions  Supabase Storage         │
│  FedaPay API      Google Maps API  Google Geocoding API     │
└─────────────────────────────────────────────────────────────┘
```

### Principes architecturaux

- **Pattern Provider + ChangeNotifier** : gestion d'état réactive
- **Services isolés** : chaque intégration externe est encapsulée dans un service
- **Cloud Functions** : les opérations sensibles (paiement, rôles) passent toujours par le serveur
- **Offline-first** : Firestore persistance locale activée pour la résilience réseau
- **Sécurité** : aucune clé secrète dans le code client — tout via `.env` et Cloud Functions

---

## 3. Stack technique et dépendances

### Dépendances principales

| Package | Version | Usage |
|---|---|---|
| `flutter` | SDK | Framework UI |
| `provider` | ^6.1.2 | Gestion d'état |
| `firebase_core` | ^4.5.0 | Initialisation Firebase |
| `firebase_auth` | ^6.2.0 | Authentification utilisateur |
| `cloud_firestore` | ^6.1.3 | Base de données temps réel |
| `firebase_messaging` | ^16.1.3 | Notifications push (FCM) |
| `firebase_storage` | ^13.1.0 | Stockage fichiers Firebase |
| `cloud_functions` | ^6.2.0 | Appel Cloud Functions |
| `google_maps_flutter` | ^2.6.1 | Carte interactive |
| `google_maps_flutter_android` | ^2.0.0 | Rendu Android (Hybrid Composition) |
| `geolocator` | ^14.0.2 | GPS device |
| `geocoding` | ^4.0.0 | Géocodage inverse (fallback) |
| `supabase_flutter` | ^2.12.4 | Stockage photos profil |
| `webview_flutter` | ^4.8.0 | Paiement FedaPay checkout |
| `url_launcher` | ^6.2.0 | Appels, WhatsApp, liens |
| `flutter_local_notifications` | ^21.0.0 | Notifications locales |
| `flutter_dotenv` | ^6.0.0 | Variables d'environnement |
| `google_sign_in` | ^7.2.0 | Connexion Google |
| `http` | ^1.2.0 | Requêtes REST (Places API, Geocoding) |
| `shared_preferences` | ^2.5.4 | Stockage local léger |
| `intl` | any | Formatage dates/nombres |
| `shimmer` | ^3.0.0 | Effets de chargement |
| `cached_network_image` | ^3.3.0 | Cache images réseau |
| `pdf` + `printing` | ^3/^5 | Génération reçus PDF |
| `qr_flutter` | ^4.1.0 | QR code commande |

---

## 4. Structure du projet

```
flutter_application_2/
├── lib/
│   ├── main.dart                    # Point d'entrée, AuthGate, MainScaffold, FCM
│   ├── firebase_options.dart        # Config Firebase auto-générée
│   ├── favorites_provider.dart      # Provider favoris (racine)
│   ├── theme_provider.dart          # Provider thème (racine)
│   │
│   ├── config/
│   │   └── env_config.dart          # Lecture variables .env
│   │
│   ├── l10n/
│   │   └── app_localizations.dart   # Chaînes i18n (FR/EN/Fon/Yoruba)
│   │
│   ├── models/
│   │   ├── cart_model.dart          # Panier (CartProvider + CartItem)
│   │   ├── delivery_model.dart      # Calcul frais livraison, DeliveryLocation
│   │   ├── order_model.dart         # Modèle commande Firestore
│   │   ├── restaurant_model.dart    # Modèle restaurant
│   │   ├── review_model.dart        # Modèle avis
│   │   └── user_model.dart          # Modèle profil utilisateur
│   │
│   ├── pages/
│   │   ├── LoginPage.dart           # Connexion / inscription
│   │   ├── RegisterPage.dart        # Création compte
│   │   ├── homepage.dart            # Accueil (bannières, suggestions)
│   │   ├── restaurantpage.dart      # Liste restaurants
│   │   ├── restaurant_detail_page.dart  # Détail restaurant + menu
│   │   ├── RestaurantProfilPage.dart    # Profil public restaurant
│   │   ├── plat_detail_page.dart    # Détail d'un plat
│   │   ├── PanierPage.dart          # Panier
│   │   ├── adressePage.dart         # Sélection adresse livraison (Google Maps)
│   │   ├── AdressesPage.dart        # Gestion adresses enregistrées
│   │   ├── RecapPage.dart           # Récapitulatif commande avant paiement
│   │   ├── PaiementPage.dart        # Paiement Mobile Money (MTN/Moov/Celtis)
│   │   ├── fedapay_checkout_page.dart   # Fallback WebView paiement FedaPay
│   │   ├── WaitingPage.dart         # Attente confirmation restaurant
│   │   ├── TrackingPage.dart        # Suivi commande temps réel (carte)
│   │   ├── OrderHistoryPage.dart    # Historique commandes
│   │   ├── NotificationsPage.dart   # Centre de notifications
│   │   ├── ProfilPage.dart          # Profil utilisateur
│   │   ├── SettingsScreen.dart      # Paramètres (langue, thème, compte)
│   │   ├── LoyaltyPage.dart         # Programme de fidélité
│   │   ├── promo_page.dart          # Codes promotionnels
│   │   ├── chat_page.dart           # Chat en temps réel avec livreur
│   │   ├── SupportPage.dart         # Support / aide
│   │   ├── SecurityPage.dart        # Sécurité du compte
│   │   ├── PrivacyPage.dart         # Politique de confidentialité
│   │   └── TermsPage.dart           # CGU — acceptation obligatoire
│   │
│   ├── providers/
│   │   ├── active_order_notifier.dart   # Suivi commande active (bannière flottante)
│   │   ├── favorites_provider.dart      # Restaurants/plats favoris
│   │   ├── language_provider.dart       # Langue de l'interface
│   │   ├── notification_provider.dart   # Badge notifications
│   │   ├── pending_order_provider.dart  # Commande en attente de paiement
│   │   └── theme_provider.dart          # Mode clair/sombre
│   │
│   ├── repositories/
│   │   └── user_repository.dart     # Accès données utilisateur Firestore
│   │
│   ├── services/
│   │   ├── api_service.dart         # Appels API génériques
│   │   ├── cloudinary_service.dart  # Upload images (Cloudinary)
│   │   ├── fcm_service.dart         # Initialisation Firebase Messaging
│   │   ├── fedapay_service.dart     # Client FedaPay (via Cloud Functions)
│   │   ├── local_notification_service.dart  # Notifications locales Android/iOS
│   │   ├── payment_service.dart     # Orchestration paiement complet
│   │   ├── receipt_service.dart     # Génération reçu PDF
│   │   ├── storage_service.dart     # Upload fichiers (Supabase/Firebase)
│   │   └── TrackingPage.dart        # Service tracking GPS background
│   │
│   └── widgets/
│       ├── ad_banner_widget.dart    # Bannière publicitaire
│       ├── ad_carousel.dart         # Carrousel annonces
│       ├── allofoods_app_bar.dart   # AppBar personnalisée
│       ├── image_viewer.dart        # Visionneuse images
│       └── pending_order_banner.dart    # Bannière commande en attente
│
├── assets/
│   ├── images/                      # Logo, images statiques
│   └── fonts/Poppins/               # Police Poppins (Regular + Bold)
│
├── .env                             # Variables sensibles (NE PAS COMMITTER)
├── pubspec.yaml                     # Dépendances Flutter
└── DOCUMENTATION_TECHNIQUE.md      # Ce fichier
```

---

## 5. Pages et fonctionnalités

### 5.1 Authentification

**`LoginPage.dart`** / **`RegisterPage.dart`**

- Connexion email/mot de passe via Firebase Auth
- Connexion Google (OAuth2 via `google_sign_in`)
- Inscription avec création du profil Firestore
- Acceptation obligatoire des CGU avant accès (`TermsPage`)
- `AuthGate` dans `main.dart` : vérifie l'état de connexion en temps réel + acceptation CGU

**Flux d'authentification :**
```
App lancée → AuthGate → Firebase Auth stream
    ├── Non connecté → LoginPage
    └── Connecté → Vérifie termsAccepted dans Firestore
            ├── Non accepté → TermsAcceptancePage
            └── Accepté → MainScaffold (5 onglets)
```

### 5.2 Accueil et navigation

**`main.dart` — `MainScaffold`**

Navigation par `PageView` avec 5 onglets :

| Index | Onglet | Page | Description |
|---|---|---|---|
| 0 | Accueil | `Homepage` | Bannières promo, restaurants suggérés |
| 1 | Restaurants | `RestaurantPage` | Liste + recherche restaurants |
| 2 | Panier | `PanierPage` | Articles sélectionnés |
| 3 | Adresse | `AdressesPage` | Adresses enregistrées |
| 4 | Profil | `ProfilPage` | Compte utilisateur |

**Bannière flottante `_ActiveOrderFAB`** : affichée en permanence quand une commande est active. Un clic redirige vers `WaitingPage` ou `TrackingPage` selon le statut.

### 5.3 Recherche de lieu et sélection d'adresse

**`adressePage.dart`**

Système de recherche en 3 niveaux par ordre de priorité :

1. **Google Places API (New)** — meilleur pour les POI nommés, autocomplete en temps réel
2. **Google Geocoding API** — fallback avec clé, retrouve les lieux précis par nom
3. **Nominatim (OpenStreetMap)** — dernier recours, sans clé API

Fonctionnalités :
- Déplacer le marqueur sur la carte → géocodage inverse automatique
- Bouton GPS → position actuelle
- Adresses récentes (Firestore `users/{uid}/recentAddresses`)
- Calcul automatique des frais de livraison selon distance
- Adresses enregistrées (Domicile / Travail / Personnalisé)

### 5.4 Panier et récapitulatif

**`PanierPage.dart`** → **`RecapPage.dart`**

- `CartProvider` : gestion en mémoire du panier (articles, restaurant, totaux)
- `RecapPage` : affiche le récap final avec frais de livraison + service avant paiement
- Validation : un seul restaurant par panier

### 5.5 Paiement Mobile Money

**`PaiementPage.dart`** → **`fedapay_checkout_page.dart`**

Voir section [10. Paiement Mobile Money](#10-paiement-mobile-money--fedapay).

### 5.6 Suivi de commande

**`WaitingPage.dart`** → **`TrackingPage.dart`**

- `WaitingPage` : statuts `paid`, `preparing`, `ready_for_pickup` — attente restaurant
- `TrackingPage` : statut `en_route` — carte temps réel avec position livreur

Voir section [11. Géolocalisation et tracking](#11-géolocalisation-et-tracking-en-temps-réel).

### 5.7 Chat en temps réel

**`chat_page.dart`**

- Messages Firestore : `orders/{orderId}/messages`
- Synchro temps réel via `snapshots()`
- Client et livreur peuvent s'écrire mutuellement

---

## 6. Gestion d'état — Providers

Tous les providers sont initialisés dans `main.dart` via `MultiProvider`.

### `CartProvider` (`models/cart_model.dart`)

Gère le panier d'achat.

| Propriété | Type | Description |
|---|---|---|
| `items` | `List<CartItem>` | Articles dans le panier |
| `itemCount` | `int` | Nombre total d'articles |
| `totalPrice` | `int` | Montant total (FCFA) |
| `restaurantId` | `String` | Restaurant du panier |
| `restaurantName` | `String` | Nom du restaurant |

Méthodes clés :
- `addItem(item)` — ajoute un article
- `removeItem(id)` — retire un article
- `clear()` — vide le panier
- `updateQuantity(id, qty)` — modifie la quantité

### `DeliveryProvider` (`models/delivery_model.dart`)

Gère l'adresse et les frais de livraison.

| Propriété | Type | Description |
|---|---|---|
| `restaurantPos` | `LatLngPoint` | Coordonnées du restaurant |
| `clientPos` | `LatLngPoint` | Coordonnées client |
| `deliveryAddress` | `String` | Adresse textuelle |
| `distanceKm` | `double` | Distance calculée |

### `ActiveOrderNotifier` (`providers/active_order_notifier.dart`)

Surveille la commande active en temps réel.

| Propriété | Type | Description |
|---|---|---|
| `orderId` | `String?` | ID commande en cours |
| `status` | `String?` | Statut actuel |
| `showBanner` | `bool` | Afficher la bannière flottante |
| `totalAmount` | `int` | Montant de la commande |
| `restaurantName` | `String?` | Nom du restaurant |

Méthodes :
- `startWatching(uid)` — démarre l'écoute Firestore
- `stopWatching()` — arrête l'écoute
- `setOrderPageOpen(bool)` — masque la bannière si la page tracking est ouverte

### `NotificationProvider`

Compteur de notifications non lues. `increment()` / `markAllRead()`.

### `ThemeProvider`

Mode clair/sombre. `toggleTheme()`. Persisté dans `SharedPreferences`.

### `LanguageProvider`

Langue de l'interface. Langues supportées : `fr`, `en`, `fon`, `yo`.

### `FavoritesProvider`

Restaurants/plats favoris. Persisté dans Firestore `users/{uid}/favorites`.

---

## 7. Modèles de données

### Collection Firestore `users/{uid}`

```json
{
  "name": "Jean Dupont",
  "email": "jean@example.com",
  "phone": "22997000000",
  "photoUrl": "https://...",
  "role": "client",
  "termsAccepted": true,
  "termsAcceptedAt": "Timestamp",
  "fcmToken": "...",
  "createdAt": "Timestamp",
  "lastSeen": "Timestamp"
}
```

Sous-collections :
- `users/{uid}/notifications` — historique notifications
- `users/{uid}/savedAddresses` — adresses enregistrées
- `users/{uid}/recentAddresses` — 7 dernières adresses utilisées
- `users/{uid}/favorites` — restaurants/plats favoris

### Collection Firestore `orders/{orderId}`

```json
{
  "clientUid": "uid",
  "clientName": "Jean Dupont",
  "clientEmail": "jean@example.com",
  "restaurantId": "rest123",
  "restaurantName": "Restaurant X",
  "restaurantLat": 6.365,
  "restaurantLng": 2.418,
  "clientLat": 6.370,
  "clientLng": 2.420,
  "deliveryAddress": "Rue des Cocotiers, Cotonou",
  "items": [...],
  "totalAmount": 3500,
  "foodAmount": 2500,
  "deliveryFee": 800,
  "serviceFee": 200,
  "status": "en_route",
  "paymentStatus": "PAID",
  "paymentMethod": "momo",
  "transactionId": "TXN-12345",
  "deliveryId": "driver_uid",
  "driverName": "Paul Livreur",
  "driverPhone": "22996000000",
  "driverLat": 6.368,
  "driverLng": 2.419,
  "customerLiveLat": 6.370,
  "customerLiveLng": 2.420,
  "createdAt": "Timestamp",
  "acceptedAt": "Timestamp",
  "deliveredAt": "Timestamp"
}
```

### Statuts de commande

| Statut | Description | Page affichée |
|---|---|---|
| `awaiting_payment` | Commande créée, paiement en attente | `PaiementPage` |
| `paid` | Paiement confirmé | `WaitingPage` |
| `confirmed` | Restaurant a confirmé | `WaitingPage` |
| `preparing` | En préparation | `WaitingPage` |
| `ready_for_pickup` | Prêt pour le livreur | `WaitingPage` |
| `delivering` | Livreur se dirige au restaurant | `TrackingPage` |
| `en_route` | Livreur en route vers client | `TrackingPage` |
| `delivered` | Livré | Dialog confirmation |
| `cancelled` | Annulé par client | — |
| `cancelled_by_restaurant` | Annulé par restaurant | — |

---

## 8. Services

### `FedaPayService` (`services/fedapay_service.dart`)

Interface vers les Cloud Functions FedaPay. Ne contient **aucune clé secrète**.

```dart
// Initialise une transaction et obtient le token
Future<FedaPayResult> initPayment(String orderId)

// Déclenche le push USSD Mobile Money
Future<FedaPayMomoResult> sendMomo({
  required String token,
  required String phoneNumber,
  required String operator, // 'mtn_open' | 'moov' | 'celtis'
})

// Vérifie le statut d'une transaction
Future<FedaPayStatusResult> checkStatus(String transactionId)
```

### `FcmService` (`services/fcm_service.dart`)

Initialisation Firebase Cloud Messaging :
- Demande permission notifications (iOS)
- Enregistre le token FCM dans Firestore `users/{uid}.fcmToken`
- Abonnement au topic `clients`

### `LocalNotificationService` (`services/local_notification_service.dart`)

Affichage de notifications locales sur Android et iOS :
- Canal priorité MAX pour les notifications commandes
- Canal normal pour les promotions
- Support images (notifications riches)
- `showRich(id, title, body, imageUrl, isPromo)`

### `ReceiptService` (`services/receipt_service.dart`)

Génère un reçu PDF de la commande (via package `pdf` + `printing`).

### `StorageService` (`services/storage_service.dart`)

Upload des photos de profil vers Supabase Storage.

---

## 9. Backend Firebase

### Firebase Auth

- Provider : Email/Password + Google
- Règle : toute accès Firestore nécessite une authentification valide
- Token JWT vérifié automatiquement côté règles Firestore

### Firestore — Règles de sécurité

Règles principales :
- `users/{uid}` : lecture/écriture par le propriétaire uniquement
- `orders/{orderId}` : lecture par client et livreur assigné
- `orders/{orderId}` création : client authentifié uniquement
- `restaurants` : lecture publique, écriture propriétaire restaurant uniquement

### Cloud Functions (europe-west1)

| Fonction | Description |
|---|---|
| `initFedaPayPayment` | Crée transaction FedaPay, montant vérifié côté serveur |
| `sendFedaPayMomo` | Push USSD MTN/Moov/Celtis |
| `checkFedaPayStatus` | Vérifie si transaction approuvée |

> **Important** : le montant de la commande n'est **jamais** pris du client — il est lu directement depuis Firestore par la Cloud Function.

### Firebase Messaging (FCM)

Topics utilisés :
- `clients` — diffusion à tous les clients
- `drivers` — diffusion à tous les livreurs

Types de notifications gérés :

| `type` | Déclencheur | Action dans l'app |
|---|---|---|
| `order_status` | Changement statut commande | Navigue vers WaitingPage/TrackingPage |
| `order` | Nouvelle commande | Navigue vers la commande |
| `payment_success` | Paiement confirmé | Navigue vers la commande |
| `promo` | Campagne marketing | Navigue vers le restaurant |
| `restaurant` | Promotion restaurant | Ouvre la page restaurant |
| `monthly_payout` | Remboursement | Ouvre onglet Profil |

---

## 10. Paiement Mobile Money — FedaPay

### Flux de paiement complet

```
RecapPage
    │
    └─► PaiementPage
            │
            ├─ 1. Appel Cloud Function initFedaPayPayment(orderId)
            │       └─ Retourne : { transactionId, token, paymentUrl }
            │
            ├─ 2. Détection réseau mobile (MTN / Moov / Celtis)
            │
            ├─ 3. Push USSD : Cloud Function sendFedaPayMomo(token, phone, operator)
            │       ├─ Succès → message "Confirmez sur votre téléphone"
            │       └─ Échec  → fallback WebView FedaPay (fedapay_checkout_page.dart)
            │
            └─ 4. Polling toutes les 5s : checkFedaPayStatus(transactionId)
                    ├─ status=approved → commande confirmée → WaitingPage
                    └─ Timeout 5 min  → erreur, relancer
```

### Opérateurs supportés

| Opérateur | Endpoint FedaPay | Préfixes détectés |
|---|---|---|
| MTN MoMo | `/v1/mtn_open` | `96`, `97`, `66`, `67`, `68`, `69` |
| Moov Money | `/v1/moov` | `95`, `94`, `98`, `99`, `60`, `61` |
| Celtis | `/v1/celtis` | `59`, `58`, `57` |

### Format numéro téléphone

- L'app client formate le numéro en `229XXXXXXXX` (11 chiffres avec indicatif)
- La Cloud Function `sendFedaPayMomo` extrait les 8 derniers chiffres locaux
- FedaPay reçoit : `{ number: "XXXXXXXX", country: "bj" }` (8 chiffres, pays minuscule)

---

## 11. Géolocalisation et tracking en temps réel

### Architecture du tracking

```
                    Firestore orders/{orderId}
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    driverLat/Lng    customerLiveLat/Lng   status
         │                 │
         ▲                 ▲
         │                 │
  Driver App           Client App
  (toutes les 5s)   (quand en_route)
```

### Côté client — `TrackingPage.dart`

**Écoute temps réel :**
```dart
FirebaseFirestore.instance
    .collection('orders')
    .doc(orderId)
    .snapshots()  // ← déclenché à chaque changement
    .listen(_onOrderData);
```

**Envoi position client (quand `en_route`) :**
```dart
Geolocator.getPositionStream(
  locationSettings: LocationSettings(accuracy: high, distanceFilter: 10),
).listen((pos) {
  // Met à jour customerLiveLat/customerLiveLng dans Firestore
});
```

**Polyline sur la carte :** Restaurant → Livreur → Client (ligne orange pointillée), visible uniquement quand `status == 'en_route'`.

### Côté livreur — `driver_provider.dart`

- Position envoyée toutes les **5 secondes** quand commande active
- Position envoyée toutes les **15 secondes** quand en ligne sans commande
- Écrit `driverLat`/`driverLng` dans `orders/{orderId}` ET `users/{driverUid}.lat/lng`

### Marqueurs sur la carte client

| Marqueur | Couleur | Condition |
|---|---|---|
| Restaurant | Orange | Toujours si coordonnées disponibles |
| Client (vous) | Bleu | Toujours si coordonnées disponibles |
| Livreur | Vert | Quand `driverLat/driverLng` renseignés |

---

## 12. Notifications push — FCM

### Initialisation

`FcmService.initialize()` est appelé dans `AuthGate` après connexion :
1. Demande permission (iOS)
2. Récupère le token FCM
3. Sauvegarde dans `users/{uid}.fcmToken`
4. S'abonne au topic `clients`

### Trois états de l'app

| État | Handler | Comportement |
|---|---|---|
| **Premier plan** | `FirebaseMessaging.onMessage` | SnackBar + notification locale |
| **Arrière-plan** | `onMessageOpenedApp` | Navigation directe au tap |
| **Terminée** | `_firebaseMessagingBackgroundHandler` (top-level) | Notification locale, nav au tap |

### Envoi de notifications (côté admin)

Les notifications sont envoyées depuis l'app admin via Cloud Functions. Le token FCM de chaque utilisateur est stocké dans `users/{uid}.fcmToken`.

---

## 13. Internationalisation

L'application supporte 4 langues via `app_localizations.dart` :

| Code | Langue |
|---|---|
| `fr` | Français (défaut) |
| `en` | Anglais |
| `fon` | Fon |
| `yo` | Yoruba |

**Changer la langue :** Paramètres → Langue → sélection

Le provider `LanguageProvider` persiste le choix dans `SharedPreferences` et reconstruit l'app via `MaterialApp(locale: lang.locale)`.

---

## 14. Configuration et variables d'environnement

### Fichier `.env` (racine du projet)

```env
# Google Maps
GOOGLE_MAPS_API_KEY=AIza...

# FedaPay (ne jamais exposer en production côté client)
# Les clés FedaPay sont UNIQUEMENT dans les Cloud Functions

# Supabase (stockage photos)
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

> **Sécurité** : Le fichier `.env` ne doit **jamais** être commité dans Git. Il est listé dans `.gitignore`.

### `config/env_config.dart`

```dart
class Env {
  static String get googleMapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get supabaseUrl   => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
```

### APIs Google à activer dans Google Cloud Console

- Maps SDK for Android
- Maps SDK for iOS
- Places API (New)
- Geocoding API
- Maps JavaScript API (pour le web)

---

## 15. Guide de démarrage développeur

### Prérequis

- Flutter SDK ≥ 3.5.0
- Dart ≥ 3.5.0
- Android Studio ou VS Code avec extensions Flutter/Dart
- Compte Firebase avec projet `allofoods` configuré
- Clé API Google Maps activée

### Installation

```bash
# 1. Cloner le projet
git clone <repo_url>
cd flutter_application_2

# 2. Installer les dépendances
flutter pub get

# 3. Créer le fichier .env (ne pas committer)
cp .env.example .env
# Remplir les valeurs dans .env

# 4. Vérifier la configuration Firebase
# Le fichier google-services.json (Android) et GoogleService-Info.plist (iOS)
# doivent être présents

# 5. Lancer en développement
flutter run

# 6. Lancer en release (Android)
flutter build apk --release

# 7. Lancer en release (iOS)
flutter build ios --release
```

### Configuration Google Maps Android

Dans `android/app/src/main/AndroidManifest.xml` :
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}"/>
```

Le rendu de carte utilise **Hybrid Composition** (`useAndroidViewSurface = true`) pour éviter les crashs sur Android < 33.

---

## 16. Flux utilisateur complet

```
1. Téléchargement de l'app
       ↓
2. Inscription / Connexion
       ↓
3. Acceptation CGU (obligatoire une seule fois)
       ↓
4. Accueil → Parcourir restaurants
       ↓
5. Choisir un restaurant → Voir le menu
       ↓
6. Ajouter des plats au panier
       ↓
7. Valider le panier
       ↓
8. Sélectionner l'adresse de livraison (carte Google Maps)
       ↓
9. Récapitulatif de commande (frais inclus)
       ↓
10. Saisir le numéro Mobile Money
        ↓
11. Appui sur "Payer" → Push USSD sur téléphone
        ↓
12. Confirmer avec code secret Mobile Money
        ↓
13. Confirmation paiement → WaitingPage
        ↓
14. Restaurant confirme et prépare la commande
        ↓
15. Livreur accepte → TrackingPage (carte temps réel)
        ↓
16. Livreur arrive → Dialog "Commande livrée !"
        ↓
17. Commande dans l'historique
```

---

## 17. Support utilisateurs internes — Problèmes courants

### Problème 1 : L'utilisateur ne reçoit pas le push USSD

**Symptôme** : Après avoir tapé sur "Payer", aucune notification USSD ne s'affiche sur le téléphone.

**Causes possibles et solutions :**

| Cause | Solution |
|---|---|
| Solde Mobile Money insuffisant | Inviter l'utilisateur à recharger son compte |
| Numéro entré incorrect | Vérifier le numéro (8 chiffres, sans indicatif) |
| Opérateur mal détecté | Sélectionner manuellement l'opérateur dans l'app |
| Service FedaPay temporairement indisponible | L'app redirige automatiquement vers la page de paiement FedaPay (WebView) |
| Pas de connexion Internet | Vérifier la connexion réseau |

**Fallback automatique** : Si le push USSD échoue, l'app ouvre automatiquement la page de paiement FedaPay en WebView où l'utilisateur peut payer manuellement.

---

### Problème 2 : La commande est bloquée en statut "awaiting_payment"

**Symptôme** : L'utilisateur a payé mais la commande reste en attente.

**Vérification :**
1. Accéder à la console FedaPay et vérifier le statut de la transaction
2. Si `status = approved` dans FedaPay mais pas mis à jour dans Firestore : la Cloud Function `checkFedaPayStatus` peut être appelée manuellement
3. Dans l'app admin : forcer le statut à `paid` via la section Commandes

---

### Problème 3 : La carte ne s'affiche pas

**Symptôme** : Écran blanc ou message d'erreur à la place de Google Maps.

**Causes possibles :**
| Cause | Solution |
|---|---|
| Clé API Google Maps invalide ou non activée | Vérifier dans Google Cloud Console que "Maps SDK for Android/iOS" est activé |
| Quota Google Maps dépassé | Vérifier la facturation dans Google Cloud Console |
| Permission GPS refusée | L'utilisateur doit autoriser la localisation dans les paramètres du téléphone |
| Pas de connexion Internet | Vérifier la connexion |

---

### Problème 4 : Le livreur n'apparaît pas sur la carte

**Symptôme** : La page de tracking est ouverte mais le marqueur livreur n'est pas visible.

**Explication** : Le livreur doit être **en ligne** (toggle dans l'app livreur) pour que sa position soit transmise. La position est mise à jour toutes les 5 secondes.

**Vérification** :
- Statut commande : doit être `en_route` (pas `delivering` ou `paid`)
- Le livreur doit avoir le GPS activé et l'app en premier plan
- Vérifier dans Firestore que `driverLat`/`driverLng` sont renseignés dans le document de commande

---

### Problème 5 : L'utilisateur ne reçoit pas de notifications

**Symptôme** : Aucune notification push ne s'affiche.

**Vérifications :**
1. Les notifications sont-elles autorisées dans les paramètres du téléphone ?
2. Vérifier dans Firestore `users/{uid}.fcmToken` — le token doit être présent
3. Sur iOS : l'application doit avoir demandé la permission (`FcmService.initialize()`)
4. Vérifier que le token FCM n'est pas expiré (l'app le renouvelle automatiquement à chaque lancement)

---

### Problème 6 : L'application se ferme (crash)

**Informations à collecter :**
- Version de l'OS Android / iOS
- Modèle du téléphone
- Étape où le crash se produit
- Message d'erreur si visible

**Crashs Android connus et corrigés :**
- **SIGABRT sur Android < 33** : corrigé via `useAndroidViewSurface = true` dans `main.dart`
- **Erreur Google Maps surface** : résolu par Hybrid Composition

---

### Problème 7 : La recherche d'adresse retourne des résultats imprécis

**Symptôme** : En tapant le nom d'un lieu, les résultats montrent des numéros de rue ou des communes au lieu du lieu précis.

**Explication** : L'app utilise 3 sources de données en cascade :
1. Google Places API (New) — meilleure précision
2. Google Geocoding API — bonne précision
3. Nominatim (OpenStreetMap) — couverture limitée au Bénin

**Solution** : Si les résultats sont imprécis, l'utilisateur peut :
- Être plus spécifique dans sa recherche (ex: "Marché Dantokpa Cotonou" plutôt que "marché")
- Déplacer directement le marqueur sur la carte au bon endroit
- Utiliser le bouton GPS pour obtenir sa position actuelle

---

### Problème 8 : L'utilisateur ne peut pas créer de compte

**Symptôme** : Erreur lors de l'inscription.

**Vérifications :**
| Erreur | Cause | Solution |
|---|---|---|
| "Email déjà utilisé" | Compte existant avec cet email | Utiliser la connexion ou "Mot de passe oublié" |
| "Mot de passe trop court" | Minimum 6 caractères requis | Informer l'utilisateur |
| "Réseau indisponible" | Pas de connexion | Vérifier Internet |
| Erreur inconnue | Problème Firebase | Vérifier la console Firebase |

---

### Contacts et escalade support

| Niveau | Contact | Quand |
|---|---|---|
| L1 — Support client | Équipe support allofoods | Problèmes utilisateurs courants |
| L2 — Technique | Équipe développement | Bugs confirmés, crashs |
| L3 — Infrastructure | Administrateur Firebase | Pannes backend, quotas |

---

*Documentation générée par l'équipe technique allofoods — Cotonou, Bénin*
