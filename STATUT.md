# Statut Technique — AlloFoods

---

## Diagnostic : Calcul des frais de livraison

### Résumé
La **formule tarifaire est identique** dans les deux apps (client et livreur), mais elles calculent sur des **distances différentes**, ce qui peut créer un écart de prix.

### Formule partagée (paliers)
| Distance | Frais |
|----------|-------|
| 0 – 3 km | 500 FCFA |
| 3 – 10 km | 1 000 FCFA |
| 10 – 15 km | 1 500 FCFA |
| > 15 km | 1 500 FCFA + 100 FCFA/km supplémentaire |

### Problème identifié

| | App Client (`delivery_model.dart`) | App Livreur (`orders_page.dart`) |
|---|---|---|
| **Moment** | À la commande | À la livraison |
| **Distance mesurée** | Restaurant → adresse client (Haversine estimée) | Point de départ livreur → GPS arrivée réelle |
| **Action Firestore** | Écrit `deliveryFee` dans l'ordre | **Écrase `deliveryFee`** avec le vrai frais recalculé |

Le client voit le prix estimé au moment de la commande. Après livraison, le livreur réécrit le champ `deliveryFee` dans Firestore avec la distance GPS réelle — ce montant peut différer de ce qui a été affiché et encaissé côté client.

### Solution retenue (à implémenter)
**Option A — Verrouiller le prix à la commande**
- Le livreur enregistre la vraie distance dans un champ séparé `realDistanceKm` (déjà fait) pour les statistiques
- Le livreur **ne modifie plus** le champ `deliveryFee` dans Firestore
- Le client paie exactement ce qui était affiché, le livreur voit le même montant

**Fichier à modifier :** `c:\allofoods_driver\lib\pages\orders_page.dart`
**Ligne concernée :** `'deliveryFee': realFee,` → à supprimer de l'update Firestore

---

## À faire (diagnostic livraison)

- [ ] Supprimer la mise à jour de `deliveryFee` dans le driver app (Option A)
- [ ] Remplacer les paliers hardcodés du driver par les valeurs `Env.*` (même source que le client)

---

---

# Statut Complet — AlloFoods

> Dernière mise à jour : 2026-06-12

---

## APP CLIENT — `flutter_application_2`

### ✅ Fonctionnalités terminées

| Domaine | Détail |
|---------|--------|
| Authentification | Connexion, inscription (avec validation forte + OTP Gmail) |
| Accueil | Liste restaurants Firestore, filtres par catégorie, recherche |
| Restaurant | Page détail restaurant, menu par catégorie, fiche plat |
| Panier | Ajout/suppression plats, quantités, persistance SharedPreferences |
| Adresse | Géolocalisation GPS, recherche adresse, Google Geocoding |
| Commande | Récap commande, calcul frais livraison (Haversine), paiement KKiaPay/FedaPay |
| Suivi | Tracking livreur temps réel (Firestore stream + Google Maps + polyline) |
| Historique | Liste commandes passées, détail par commande |
| Profil | Modification profil, changement mot de passe |
| Notifications | Badge temps réel (Firestore stream), page notifications |
| Support | Chat support, tickets, page termes/confidentialité/sécurité |
| Fidélité | Page programme de fidélité |
| Promotions | Page promotions/promos |
| Données | Toutes les fausses données (RestaurantData) supprimées — Firestore uniquement |
| Tests | 79 tests unitaires + 9 tests widget passants |
| Modèles | `restaurant_model`, `order_model`, `cart_model`, `delivery_model`, `user_model`, `review_model` |

### ⚠️ Incomplet / À corriger

| Fichier | Problème | Priorité |
|---------|----------|----------|
| `lib/pages/RegisterPage.dart` | Fichier presque vide (2 bytes) — doublon avec la vraie inscription | 🔴 Haute |
| `lib/providers/theme_provider.dart` | Stub avec TODO — thème sombre non fonctionnel | 🟡 Moyenne |
| `lib/providers/favorites_provider.dart` | Stub avec TODO — favoris non sauvegardés | 🟡 Moyenne |
| `delivery_model.dart` — `deliveryFee` | Frais écrasés par le livreur après livraison (voir diagnostic ci-dessus) | 🔴 Haute |

---

## APP RESTAURANT — `allofoods_merchant`

### ✅ Fonctionnalités terminées

| Domaine | Détail |
|---------|--------|
| Authentification | Connexion, inscription multi-étapes avec OTP Gmail |
| Validation inscription | Gmail uniquement, mot de passe fort (8 car. + maj + min + chiffre + spécial) |
| Profil restaurant | Modification infos, photo logo, type de cuisine (`categorie` enregistré dans Firestore) |
| Menu | Gestion plats (ajout, modification, suppression, disponibilité) |
| Commandes | Liste commandes en temps réel, changement de statut |
| Détail commande | Vue complète avec articles et montants |
| Wallet | Solde, historique transactions, virements automatiques |
| Factures | Page invoices |
| Promotions | Gestion promos |
| Statistiques | Page stats restaurant |
| Paramètres | Page settings |
| Catégorie | Champ `categorie` enregistré à l'inscription ET lors de la mise à jour du profil |

### ⚠️ Incomplet / À corriger

| Fichier | Problème | Priorité |
|---------|----------|----------|
| Dossier `models/` | Absent — données métier non structurées en modèles Dart | 🟡 Moyenne |
| Providers | Un seul provider (`merchant_provider`) — pas de séparation par domaine | 🟡 Moyenne |
| Services | Seulement 2 services (`storage_service`, `wallet_service`) | 🟡 Moyenne |

---

## APP LIVREUR — `allofoods_driver`

### ✅ Fonctionnalités terminées

| Domaine | Détail |
|---------|--------|
| Authentification | Connexion, inscription multi-étapes avec OTP Gmail |
| Validation inscription | Gmail uniquement, mot de passe fort, nom CIP obligatoire (format vérifié) |
| Carte | Carte Google Maps avec position GPS temps réel, polyline itinéraire |
| Commandes | Liste commandes disponibles + en cours, acceptation/refus |
| Livraison | Flux complet : accepter → récupérer → livrer, confirmation GPS |
| Chat | Page chat avec client |
| Profil | Page profil livreur |
| Statistiques | Page stats livraisons |
| Gains | Page earnings avec historique |
| Approbation | Page d'attente après inscription (`pending_approval_page`) |
| Paramètres | Page settings |
| Notifications | Firebase Messaging intégré |

### ⚠️ Incomplet / À corriger

| Fichier | Problème | Priorité |
|---------|----------|----------|
| `lib/orders _page.dart` | Fichier dupliqué avec espace dans le nom (33 bytes, TODO) — à supprimer | 🔴 Haute |
| `lib/models/order_model.dart` | Fichier vide / stub | 🟡 Moyenne |
| `orders_page.dart` — `deliveryFee` | Écrase le frais client dans Firestore (voir diagnostic) | 🔴 Haute |
| `_calcFee()` | Paliers hardcodés au lieu de lire `Env.*` | 🟡 Moyenne |
| Services | Un seul service (`fedapay_service`) | 🟡 Moyenne |

---

## INFRASTRUCTURE PARTAGÉE

### ✅ Terminé

| Composant | Détail |
|-----------|--------|
| Firebase Auth | Authentification email/password sur les 3 apps |
| Firestore | Base de données temps réel pour commandes, restaurants, livreurs, clients |
| Cloud Functions | 20 fonctions déployées (notifications FCM, paiements, OTP, rapports, clôture journée) |
| OTP Gmail | `sendRegistrationOtp` + `verifyRegistrationOtp` déployées en production |
| FCM | Push notifications sur les 3 apps + auto-remplissage OTP |
| Nodemailer | Gmail SMTP configuré avec App Password — emails de reçu, OTP, support |
| FedaPay | Paiement en production (`FEDAPAY_SANDBOX=false`) |
| KKiaPay | Intégration paiement mobile |
| Clôture journée | Virement automatique restaurants à 20h (scheduledCloture) |
| Rapports | Rapport journalier automatique (dailyReport) |
| Nettoyage | Scheduled cleanup nocturne |

### ⚠️ Points d'attention

| Point | Détail | Priorité |
|-------|--------|----------|
| `.env` functions | Contient des clés de production — ne jamais committer | 🔴 Critique |
| `google-services.json` | Dans `.gitignore` — à garder hors du dépôt public | 🔴 Critique |
| Coordonnées GPS restaurants | Doivent être renseignées dans Firestore (`lat`/`lng`) sinon fallback centre Cotonou | 🔴 Haute |
| Cleanup policy us-central1 | Avertissement Firebase sur les images Docker — non bloquant | 🟢 Faible |

---

## RÉCAPITULATIF GLOBAL

| | App Client | App Restaurant | App Livreur |
|--|-----------|---------------|------------|
| Pages | 26 | 14 | 12 |
| Providers | 6 (2 stubs) | 1 | 1 |
| Models | 6 | 0 | 2 (1 vide) |
| Services | 9 | 2 | 1 |
| Tests | 88 ✅ | — | — |
| OTP inscription | ✅ | ✅ | ✅ |
| Paiement | ✅ KKiaPay + FedaPay | ✅ Wallet | ✅ Gains |
| Tracking temps réel | ✅ | — | ✅ |
| Statut global | 🟡 Quasi-complet | 🟡 Quasi-complet | 🟡 Quasi-complet |

---

## PROCHAINES ACTIONS RECOMMANDÉES (par priorité)

1. 🔴 **Corriger `deliveryFee`** — supprimer l'écrasement dans `orders_page.dart` driver
2. 🔴 **Supprimer `orders _page.dart`** (fichier fantôme avec espace dans le nom)
3. 🔴 **Vérifier `RegisterPage.dart`** client (fichier presque vide — doublon ?)
4. 🟡 **Implémenter `favorites_provider`** — sauvegarder les favoris en Firestore
5. 🟡 **Implémenter `theme_provider`** — thème sombre
6. 🟡 **Renseigner coordonnées GPS** de chaque restaurant dans Firestore
7. 🟡 **Remplacer `_calcFee()` hardcodé** par `Env.*` dans l'app livreur
