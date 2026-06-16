# AlloFoods — Application Client

> Application mobile de livraison de repas à domicile.
> Plateforme : **Flutter 3.x** | Backend : **Firebase** | Paiement : **FedaPay / KKiapay**

---

## Table des matières

1. [Présentation](#présentation)
2. [Stack technique](#stack-technique)
3. [Architecture du projet](#architecture-du-projet)
4. [Fonctionnalités](#fonctionnalités)
5. [Écrans & navigation](#écrans--navigation)
6. [Localisation](#localisation)
7. [Configuration & démarrage](#configuration--démarrage)
8. [Variables d'environnement](#variables-denvironnement)
9. [Services externes](#services-externes)

---

## Présentation

**AlloFoods Client** est l'application destinée aux clients finaux. Elle permet de :

- Parcourir les restaurants et les plats disponibles
- Commander des repas et suivre la livraison en temps réel sur Google Maps
- Payer en ligne via Mobile Money (FedaPay / KKiapay) ou en cash au livreur
- Gérer son profil, ses adresses et son historique de commandes
- Recevoir des notifications push enrichies (image + lien)
- Discuter en direct avec le livreur via le chat intégré
- Bénéficier d'un programme de fidélité avec points et récompenses

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Framework | Flutter 3.x (Dart ≥ 3.5) |
| Gestion d'état | Provider + ChangeNotifier |
| Backend temps réel | Firebase Firestore |
| Authentification | Firebase Auth + Google Sign-In |
| Stockage fichiers | Firebase Storage · Cloudinary · Supabase |
| Cloud Functions | Firebase Functions (proxy paiement, notifications promo) |
| Push | Firebase Cloud Messaging + flutter_local_notifications |
| Paiement | FedaPay (WebView) · KKiapay SDK |
| Cartes | Google Maps Flutter v2 |
| Géolocalisation | Geolocator · Geocoding · Google Places API (New) |
| PDF / Reçus | pdf · printing |
| QR Code | qr_flutter |
| WebView | webview_flutter |
| Auth sociale | google_sign_in |

---

## Architecture du projet

```
lib/
├── config/
│   └── env_config.dart              # Clés API & variables d'env
├── l10n/
│   └── app_localizations.dart       # Toutes les chaînes FR/EN/yo/fo
├── models/
│   ├── cart_model.dart              # Panier (items, quantité, prix)
│   ├── delivery_model.dart          # Informations de livraison
│   ├── order_model.dart             # Commande complète
│   ├── restaurant_model.dart        # Restaurant (nom, horaires, note)
│   ├── review_model.dart            # Avis client
│   └── user_model.dart              # Profil utilisateur
├── pages/                           # 26 écrans (voir tableau ci-dessous)
├── providers/
│   ├── active_order_notifier.dart   # Commande en cours (bannière)
│   ├── favorites_provider.dart      # Restaurants favoris
│   ├── language_provider.dart       # Langue active + persistance
│   ├── notification_provider.dart   # Compteur notifications
│   ├── pending_order_provider.dart  # Commandes en attente
│   └── theme_provider.dart          # Thème clair / sombre
├── repositories/
│   └── user_repository.dart         # Accès données utilisateur
├── services/
│   ├── api_service.dart             # Appels HTTP backend
│   ├── cloudinary_service.dart      # Upload images profil
│   ├── fcm_service.dart             # Initialisation FCM + handlers
│   ├── fedapay_service.dart         # Intégration FedaPay
│   ├── local_notification_service.dart # Notifications locales (foreground)
│   ├── payment_service.dart         # Calcul frais (commission 5%)
│   ├── receipt_service.dart         # Génération PDF reçus
│   └── storage_service.dart         # Firebase Storage
└── widgets/
    ├── ad_banner_widget.dart        # Bannière publicitaire
    ├── ad_carousel.dart             # Carousel promotionnel
    ├── custom_app_bar.dart          # AppBar personnalisé
    ├── image_viewer.dart            # Visionneuse plein écran
    └── pending_order_banner.dart    # Bannière commande active
```

---

## Fonctionnalités

### Authentification
- Connexion email / mot de passe avec validation
- Inscription (nom, email, téléphone `01XXXXXXXX`, mot de passe ≥ 6 car. avec chiffre)
- Google Sign-In
- Réinitialisation mot de passe (lien email)
- Contrôle du rôle : seuls les comptes `client` sont autorisés

### Page d'accueil
- Sections dynamiques (Offres & Promos, Petit-déjeuner, Plats populaires, Restaurants à proximité…)
- Barre de recherche (restaurant ou plat)
- Affichage de l'adresse de livraison active
- Carousel publicitaire
- Bannière "commande en cours" si une livraison est active

### Restaurants & Plats
- Fiche restaurant : note, délai estimé, horaires, galerie photos
- Menu par catégorie avec options et suppléments configurables
- Page détail du plat : photo, description, prix, suppléments (single/multi), instructions au marchand
- Favoris (❤️) persistés dans Firestore

### Panier
- Gestion des articles (quantité +/−, suppression)
- Code promo : validation Firestore (actif, non expiré, limite d'utilisations, minimum de commande)
- Calcul automatique : sous-total + commission 5% + frais de livraison
- Onglet Favoris et Historique intégrés

### Commande & Paiement
- Récapitulatif complet avant validation
- Choix paiement : **en ligne** (Mobile Money via FedaPay) ou **cash** au livreur
- WebView FedaPay sécurisé avec polling automatique (6 s) et vérification manuelle
- Sauvegarde automatique de la commande dans Firestore après paiement

### Suivi de commande
- **WaitingPage** : suivi des phases animées (paiement → préparation → prêt → en route → livré/annulé)
- **TrackingPage** : carte temps réel avec position du livreur, itinéraire, délai estimé
- Informations livreur : nom, véhicule, couleur, plaque, appel direct
- Détail paiement sur la carte
- Annulation avec motif (si pas encore en route)
- Chat direct avec le livreur

### Historique des commandes
- Onglets **Livrées** / **Échouées**
- Compteurs et résumés (livraisons effectuées, commandes échouées)
- Détail : articles, prix, adresse, date, méthode de paiement, référence transaction
- Relancer un paiement échoué
- Recommander depuis l'historique (remet les articles au panier)

### Profil utilisateur
- Modification nom et téléphone
- Photo de profil (galerie / caméra / suppression) — stockage Cloudinary
- Code membre unique `AF-YYYY-XXXX`
- Raccourcis : Paramètres, Notifications, Historique, Fidélité

### Notifications
- Liste temps réel depuis Firestore
- Sections Nouvelles / Lues avec badge de comptage
- Marquer tout comme lu / Tout supprimer
- Page détail notification avec image et lien d'action
- Push FCM : foreground (notification locale) + background (notification système)
- Support images dans les notifications (BigPicture Android)

### Paramètres
- **Langue** : Français · English · Yoruba · Fon (persisté)
- **Thème** : Clair / Sombre (persisté)
- Sécurité, CGU, Politique de confidentialité, Centre d'aide, Signaler un problème

### Programme de fidélité
- Points accumulés à chaque commande
- Paliers et récompenses
- Historique des transactions de points

---

## Écrans & navigation

| Fichier | Rôle |
|---------|------|
| `homepage.dart` | Accueil — fil des restaurants et sections |
| `LoginPage.dart` | Connexion / Inscription (onglets) |
| `restaurant_detail_page.dart` | Fiche restaurant + menu |
| `RestaurantProfilPage.dart` | Profil complet restaurant |
| `plat_detail_page.dart` | Détail d'un plat + suppléments |
| `restaurantpage.dart` | Liste de restaurants |
| `PanierPage.dart` | Panier + Favoris + Historique |
| `RecapPage.dart` | Récapitulatif avant paiement |
| `PaiementPage.dart` | Déclenchement du paiement |
| `fedapay_checkout_page.dart` | WebView FedaPay |
| `adressePage.dart` | Sélection / ajout d'adresse (Places API) |
| `AdressesPage.dart` | Gestion de mes adresses |
| `WaitingPage.dart` | Suivi phases commande |
| `TrackingPage.dart` | Carte suivi en temps réel |
| `chat_page.dart` | Chat avec le livreur |
| `NotificationsPage.dart` | Centre de notifications |
| `OrderHistoryPage.dart` | Historique des commandes |
| `ProfilPage.dart` | Mon profil |
| `SettingsScreen.dart` | Paramètres |
| `SecurityPage.dart` | Sécurité (mot de passe, biométrie) |
| `SupportPage.dart` | Centre d'aide / FAQ |
| `LoyaltyPage.dart` | Programme fidélité |
| `promo_page.dart` | Offres promotionnelles |
| `TermsPage.dart` | Conditions d'utilisation |
| `PrivacyPage.dart` | Politique de confidentialité |
| `RegisterPage.dart` | Inscription (flux alternatif) |

---

## Localisation

Le système de localisation est entièrement custom (`AppLocalizations`) et supporte **4 langues** :

| Code | Langue |
|------|--------|
| `fr` | Français (défaut) |
| `en` | English |
| `yo` | Yoruba |
| `fo` | Fon |

La langue sélectionnée est persistée via `SharedPreferences` et réactive grâce à `LanguageProvider`.

```dart
// Utilisation dans un widget
final t = AppLocalizations.of(context);
Text(t.myOrders)
Text(t.deliveriesCount(5))          // '$n livraisons effectuées'
Text(t.thankyouOrdered('Le Gourmet')) // 'Merci d'avoir commandé chez...'
```

---

## Configuration & démarrage

### Prérequis

- Flutter SDK ≥ 3.5.0
- Dart ≥ 3.5.0
- Compte Firebase (projet configuré)
- Clé API Google Maps (Places New + Maps)
- Compte FedaPay (sandbox ou production)
- Compte Cloudinary

### Installation

```bash
# 1. Cloner le projet
git clone <repo_url>
cd flutter_application_2

# 2. Installer les dépendances Flutter
flutter pub get

# 3. Fichiers Firebase
# Android : placer google-services.json dans android/app/
# iOS     : placer GoogleService-Info.plist dans ios/Runner/

# 4. Remplir lib/config/env_config.dart avec vos clés
# (voir section Variables d'environnement)

# 5. Lancer en mode debug
flutter run
```

### Build production

```bash
# APK Android signé
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## Variables d'environnement

À configurer dans `lib/config/env_config.dart` :

| Variable | Description |
|----------|-------------|
| `googleMapsApiKey` | Clé API Google Maps (Places New + SDK Android/iOS) |
| `fedaPayPublicKey` | Clé publique FedaPay |
| `cloudinaryCloudName` | Nom du cloud Cloudinary |
| `cloudinaryUploadPreset` | Preset d'upload non signé |
| `backendBaseUrl` | URL base des Cloud Functions Firebase |
| `supabaseUrl` | URL du projet Supabase |
| `supabaseAnonKey` | Clé anon Supabase |

---

## Services externes

| Service | Rôle dans l'app |
|---------|----------------|
| **Firebase Auth** | Connexion email/password + Google OAuth |
| **Cloud Firestore** | Utilisateurs, commandes, restaurants, notifications, promos |
| **Firebase Storage** | Images de profil (backup) |
| **Cloud Functions** | Proxy FedaPay sécurisé · Envoi notifications promo |
| **Firebase Messaging** | Push notifications commandes et promos |
| **Google Maps** | Affichage carte · suivi livreur · itinéraire |
| **Google Places API (New)** | Autocomplétion et géocodage adresses |
| **FedaPay** | Paiement Mobile Money (MTN MoMo · Moov Money) |
| **KKiapay** | Paiement alternatif |
| **Cloudinary** | Upload et transformation images de profil |
| **Supabase** | Stockage complémentaire |

---

*AlloFoods — Livraison rapide 🛵 · Made in Bénin 🇧🇯*
