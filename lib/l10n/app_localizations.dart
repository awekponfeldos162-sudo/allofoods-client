// lib/l10n/app_localizations.dart
//
// Utilisation dans un widget :
//   final t = AppLocalizations.of(context);
//   Text(t.home)        // ? "Accueil" ou "Home" selon la langue

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)
        ?? const AppLocalizations(Locale('fr'));
  }

  static const delegate = _AppLocalizationsDelegate();

  // Récupére la bonne traduction
  String _t(Map<String, String> translations) {
    return translations[locale.languageCode]
        ?? translations['fr']
        ?? '';
  }

  // NAVIGATION
  String get home         => _t({'fr': 'Accueil',      'en': 'Home',          'yo': 'Ilé',        'fo': 'Xwé'});
  String get restaurants  => _t({'fr': 'Restaurants',  'en': 'Restaurants',   'yo': 'Ilé onj?',   'fo': 'Hotelinu'});
  String get cart         => _t({'fr': 'Panier',       'en': 'Cart',          'yo': 'Agb?n',      'fo': 'Panier'});
  String get address      => _t({'fr': 'Adresse',      'en': 'Address',       'yo': 'édér??sé',   'fo': 'Adresse'});
  String get profile      => _t({'fr': 'Profil',       'en': 'Profile',       'yo': 'Profaili',   'fo': 'Profil'});

  // ACCUEIL
  String get heroTitle    => _t({'fr': 'Livraison rapide ??', 'en': 'Fast delivery ??', 'yo': 'Ifiran?? yéra ??', 'fo': 'Fi?o?o j??j?? ??'});
  String get heroSubtitle => _t({'fr': 'Commandez vos plats préférés', 'en': 'Order your favourite meals', 'yo': 'Pa?? ounj? ayanf? r?', 'fo': 'Blé nébléné e jlé'});
  String get sectionFeatured => _t({'fr': 'Nos Restaurants',          'en': 'Our Restaurants',     'yo': 'éw?n Ilé onj? wa',  'fo': 'M? t?n Hotelinu'});
  String get sectionDaily    => _t({'fr': 'Sélections du jour',       'en': 'Today\'s picks',      'yo': 'Yéyan ?j? yéé',     'fo': 'Té sén égbé t?n'});
  String get sectionExplore  => _t({'fr': "Explorer d'autres saveurs",'en': 'Explore more flavours','yo': '?éwéré éw?n adun', 'fo': 'Kp??n nébléné ?evo'});
  String get endOfPage       => _t({'fr': 'Vous avez tout vu ! ??',   'en': 'You\'ve seen it all! ??','yo': 'O ti ré gbogbo r?! ??','fo': '?é ali ?é o kp??n! ??'});
  String get seeAllRestaurants => _t({'fr': 'Voir tous les restaurants','en': 'See all restaurants','yo': 'Wo gbogbo ilé onj?', 'fo': 'Kp??n hotelinu b?'});

  // PROFIL
  String get editProfile   => _t({'fr': 'Modifier le profil',  'en': 'Edit profile',    'yo': '?étén?e profaili', 'fo': 'Profil bl??'});
  String get save          => _t({'fr': 'Enregistrer',         'en': 'Save',            'yo': 'Pam??',             'fo': 'L??n'});
  String get saving        => _t({'fr': 'Enregistrement...',   'en': 'Saving...',       'yo': '? pam??...',        'fo': '?é l??n w?...'});
  String get logout        => _t({'fr': 'Déconnexion',         'en': 'Logout',          'yo': 'Jéde',             'fo': 'Yé sé'});
  String get activeAccount => _t({'fr': 'Compte actif',        'en': 'Active account',  'yo': 'éké?té té ? ?i???','fo': 'Ak?? nyé w?'});

  // PARAMéTRES
  String get settings      => _t({'fr': 'Paramétres',          'en': 'Settings',        'yo': 'été',              'fo': 'N? ?é'});
  String get security      => _t({'fr': 'Sécurité',            'en': 'Security',        'yo': 'Aabo',             'fo': 'Gb?????gb??'});
  String get language      => _t({'fr': 'Langue',              'en': 'Language',        'yo': 'édé',              'fo': 'Gbé'});
  String get notifications => _t({'fr': 'Notifications',       'en': 'Notifications',   'yo': 'éwéfén',           'fo': 'N? xl??'});
  String get chooseLanguage => _t({'fr': 'Choisir la langue',  'en': 'Choose language', 'yo': 'Yan édé',          'fo': 'S? gbé'});

  // PANIER & PAIEMENT
  String get myCart        => _t({'fr': 'Mon panier',          'en': 'My cart',         'yo': 'Agb?n mi',         'fo': 'Panier ce'});
  String get total         => _t({'fr': 'Total',               'en': 'Total',           'yo': 'épap??',           'fo': 'L? b?'});
  String get pay           => _t({'fr': 'Payer',               'en': 'Pay',             'yo': 'San',              'fo': 'S? hw?'});
  String get payment       => _t({'fr': 'Paiement',            'en': 'Payment',         'yo': 'ésanwé',          'fo': 'Hw? s?'});
  String get deliveryFee   => _t({'fr': 'Frais de livraison',  'en': 'Delivery fee',    'yo': 'Owé ifiran??',    'fo': 'Fi?o?o t?n'});
  String get emptyCart     => _t({'fr': 'Votre panier est vide','en': 'Your cart is empty','yo': 'Agb?n r? é kén','fo': 'Panier towe kén ?'});

  // COMMANDES
  String get myOrders      => _t({'fr': 'Mes commandes',       'en': 'My orders',       'yo': 'éw?n a?? mi',     'fo': 'Blé ce l?'});
  String get orderStatus   => _t({'fr': 'Statut',              'en': 'Status',          'yo': 'Ipé',              'fo': 'N? ?é'});
  String get delivered     => _t({'fr': 'Livré',               'en': 'Delivered',       'yo': 'é ti dé',          'fo': 'Fi?o wé'});
  String get preparing     => _t({'fr': 'En préparation',      'en': 'Preparing',       'yo': '? pésé',           'fo': '?é s? w?'});
  String get onTheWay      => _t({'fr': 'En livraison',        'en': 'On the way',      'yo': '? b??',            'fo': '?é wé w?'});
  String get cancelled     => _t({'fr': 'Annulé',              'en': 'Cancelled',       'yo': 'Par??',            'fo': 'Cé'});

  // ERREURS & MESSAGES
  String get error         => _t({'fr': 'Erreur',              'en': 'Error'});
  String get success       => _t({'fr': 'Succès',              'en': 'Success'});
  String get cancel        => _t({'fr': 'Annuler',             'en': 'Cancel'});
  String get confirm       => _t({'fr': 'Confirmer',           'en': 'Confirm'});
  String get loading       => _t({'fr': 'Chargement...',       'en': 'Loading...'});
  String get noResults     => _t({'fr': 'Aucun résultat',      'en': 'No results'});
  String get search        => _t({'fr': 'Rechercher...',       'en': 'Search...'});

  // PARAMÈTRES — sections
  String get account       => _t({'fr': 'Compte',              'en': 'Account'});
  String get localization  => _t({'fr': 'Localisation',        'en': 'Localization'});
  String get assistance    => _t({'fr': 'Assistance',          'en': 'Support'});
  String get legal         => _t({'fr': 'Légal',               'en': 'Legal'});

  // PARAMÈTRES — tuiles Compte
  String get personalInfo  => _t({'fr': 'Informations personnelles', 'en': 'Personal information'});
  String get personalInfoSub => _t({'fr': 'Nom, email, téléphone',  'en': 'Name, email, phone'});
  String get savedAddresses => _t({'fr': 'Adresses sauvegardées',   'en': 'Saved addresses'});
  String get savedAddressesSub => _t({'fr': 'Gérer vos adresses de livraison', 'en': 'Manage your delivery addresses'});
  String get orderHistory  => _t({'fr': 'Historique des commandes', 'en': 'Order history'});
  String get orderHistorySub => _t({'fr': 'Voir toutes vos commandes', 'en': 'View all your orders'});

  // PARAMÈTRES — tuiles Sécurité
  String get changePassword => _t({'fr': 'Changer le mot de passe',     'en': 'Change password'});
  String get changePasswordSub => _t({'fr': 'Modifier votre mot de passe actuel', 'en': 'Update your current password'});
  String get biometric     => _t({'fr': 'Authentification biométrique', 'en': 'Biometric authentication'});
  String get biometricSub  => _t({'fr': 'Déverrouillez avec empreinte ou face ID', 'en': 'Unlock with fingerprint or face ID'});

  // PARAMÈTRES — tuiles Notifications
  String get orderNotifs   => _t({'fr': 'Statut des commandes',    'en': 'Order status'});
  String get orderNotifsSub => _t({'fr': 'Mises à jour en temps réel', 'en': 'Real-time updates'});
  String get promoNotifs   => _t({'fr': 'Promotions & offres',     'en': 'Promotions & offers'});
  String get promoNotifsSub => _t({'fr': 'Réductions et nouveautés', 'en': 'Discounts and news'});

  // PARAMÈTRES — tuiles Localisation
  String get languageSub   => _t({'fr': 'Langue de l\'interface',  'en': 'Interface language'});
  String get darkMode      => _t({'fr': 'Mode sombre',             'en': 'Dark mode'});
  String get darkModeSub   => _t({'fr': 'Thème sombre pour économiser la batterie', 'en': 'Dark theme to save battery'});

  // PARAMÈTRES — tuiles Assistance
  String get helpCenter    => _t({'fr': 'Centre d\'aide',          'en': 'Help center'});
  String get helpCenterSub => _t({'fr': 'FAQ et résolution de problèmes', 'en': 'FAQ and troubleshooting'});
  String get reportIssue   => _t({'fr': 'Signaler un problème',    'en': 'Report an issue'});
  String get reportIssueSub => _t({'fr': 'Commandes, paiements, livraison', 'en': 'Orders, payments, delivery'});
  String get checkConnection => _t({'fr': 'Vérifier la connexion', 'en': 'Check connection'});
  String get checkConnectionSub => _t({'fr': 'Tester la connexion au serveur', 'en': 'Test server connection'});

  // PARAMÈTRES — tuiles Légal
  String get privacyPolicy => _t({'fr': 'Politique de confidentialité', 'en': 'Privacy policy'});
  String get termsOfUse    => _t({'fr': 'Conditions d\'utilisation',    'en': 'Terms of use'});
  String get appVersion    => _t({'fr': 'Version de l\'application',    'en': 'App version'});

  // PARAMÈTRES — actions
  String get signOut       => _t({'fr': 'Se déconnecter',         'en': 'Sign out'});
  String get signOutConfirmTitle => _t({'fr': 'Se déconnecter ?', 'en': 'Sign out?'});
  String get signOutConfirmBody  => _t({'fr': 'Vous devrez vous reconnecter pour commander.', 'en': 'You will need to sign in again to order.'});
  String get disconnect    => _t({'fr': 'Déconnecter',            'en': 'Sign out'});

  // ACCUEIL — sections
  String get offersAndPromos       => _t({'fr': 'Offres & Promotions',           'en': 'Offers & Promotions'});
  String get breakfast             => _t({'fr': 'Petit déjeuner',                'en': 'Breakfast'});
  String get popularDishes         => _t({'fr': 'Plats Populaires',              'en': 'Popular Dishes'});
  String get lunchDishes           => _t({'fr': 'Plats du Midi',                 'en': 'Lunch Dishes'});
  String get restaurantsNearby     => _t({'fr': 'Restaurant pour vos proches',   'en': 'Restaurants Nearby'});
  String get otherRestaurants      => _t({'fr': "D'autres restaurants",          'en': 'More Restaurants'});
  String get noRestaurantsAvailable => _t({'fr': 'Aucun restaurant disponible',  'en': 'No restaurants available'});
  String get comeBackSoon          => _t({'fr': 'Revenez bientôt !',             'en': 'Come back soon!'});
  String get deliveryTo            => _t({'fr': 'Livraison à',                   'en': 'Delivery to'});
  String get searchHint            => _t({'fr': 'Rechercher un restaurant ou un plat', 'en': 'Search a restaurant or dish'});
  String get seeAll                => _t({'fr': 'Voir tout',                     'en': 'See all'});
  String get seeMoreRestaurants    => _t({'fr': 'Voir plus de restaurants',      'en': 'See more restaurants'});

  // ATTENTE COMMANDE (WaitingPage)
  String get paymentConfirmed      => _t({'fr': 'Paiement confirmé',             'en': 'Payment confirmed'});
  String get inPreparation         => _t({'fr': 'En préparation',                'en': 'Preparing'});
  String get orderReady            => _t({'fr': 'Commande prête',                'en': 'Order ready'});
  String get orderDelivered        => _t({'fr': 'Commande livrée',               'en': 'Order delivered'});
  String get orderCancelled        => _t({'fr': 'Commande annulée',              'en': 'Order cancelled'});
  String get paymentReceived       => _t({'fr': 'Paiement reçu',                 'en': 'Payment received'});
  String get restaurantWillPrepare => _t({'fr': 'Le restaurant va commencer la préparation de votre commande.', 'en': 'The restaurant will start preparing your order.'});
  String get awaitingPreparation   => _t({'fr': 'En attente de préparation',     'en': 'Awaiting preparation'});
  String get orderInPreparation    => _t({'fr': 'Commande en préparation',       'en': 'Order in preparation'});
  String get restaurantPreparingWithCare => _t({'fr': 'Le restaurant prépare vos plats avec soin.', 'en': 'The restaurant is preparing your dishes with care.'});
  String get preparationInProgress => _t({'fr': 'Préparation en cours',          'en': 'Preparation in progress'});
  String get yourOrderIsReady      => _t({'fr': 'Votre commande est prête !',    'en': 'Your order is ready!'});
  String get driverTakingCharge    => _t({'fr': 'Un livreur prend en charge votre commande, merci de patienter.', 'en': 'A driver is taking charge of your order, please wait.'});
  String get searchingForDriver    => _t({'fr': 'Recherche d\'un livreur...',    'en': 'Searching for a driver...'});
  String get orderOnTheWay         => _t({'fr': 'Votre commande est en route !', 'en': 'Your order is on the way!'});
  String get driverHeadingToYou   => _t({'fr': 'Le livreur se dirige vers vous.','en': 'The driver is heading your way.'});
  String get redirectingToTracking => _t({'fr': 'Redirection vers le suivi...',  'en': 'Redirecting to tracking...'});
  String get estimatedDelivery     => _t({'fr': 'Livraison estimée : ~30-45 min','en': 'Estimated delivery: ~30-45 min'});
  String get exitDialogTitle       => _t({'fr': 'Quitter ?',                     'en': 'Leave?'});
  String get exitDialogMessage     => _t({'fr': 'Votre commande est en cours. Vous pouvez la retrouver depuis l\'accueil.', 'en': 'Your order is in progress. You can find it from the home screen.'});
  String get stay                  => _t({'fr': 'Rester',                        'en': 'Stay'});
  String get leave                 => _t({'fr': 'Quitter',                       'en': 'Leave'});
  String get deliveryDone          => _t({'fr': 'Livraison effectuée !',         'en': 'Delivery done!'});
  String get returnHome            => _t({'fr': 'Retour à l\'accueil',           'en': 'Back to home'});
  String get refundInfo            => _t({'fr': 'Si vous avez été débité, vous serez remboursé sous 24h à 48h via FedaPay.', 'en': 'If charged, you will be refunded within 24-48 hours via FedaPay.'});
  String get cancelOrderDialog     => _t({'fr': 'Annuler la commande ?',         'en': 'Cancel order?'});
  String get cancelOrderWarning    => _t({'fr': 'Une fois acceptée par le restaurant, l\'annulation peut ne plus être possible.', 'en': 'Once accepted by the restaurant, cancellation may no longer be possible.'});
  String get reason                => _t({'fr': 'Raison :',                      'en': 'Reason:'});
  String get cancelReasonChangedMind => _t({'fr': 'J\'ai changé d\'avis',       'en': 'I changed my mind'});
  String get cancelReasonTooLong   => _t({'fr': 'Délai trop long',               'en': 'Too long wait'});
  String get cancelReasonOrderError => _t({'fr': 'Erreur de commande',           'en': 'Order error'});
  String get cancelReasonOther     => _t({'fr': 'Autre',                         'en': 'Other'});
  String get keepMyOrder           => _t({'fr': 'Non, je garde ma commande',     'en': 'No, keep my order'});
  String get cancellingOrder       => _t({'fr': 'Annulation',                    'en': 'Cancelling'});
  String get cancelOrderBtn        => _t({'fr': 'Annuler la commande',           'en': 'Cancel order'});
  String thankyouOrdered(String name) => _t({'fr': 'Merci d\'avoir commandé chez $name.\nBon appétit !', 'en': 'Thank you for ordering from $name.\nEnjoy your meal!'});
  String restaurantRefused(String name) => _t({'fr': '$name a refusé votre commande.', 'en': '$name refused your order.'});

  // SUIVI (TrackingPage)
  String get statusPending         => _t({'fr': 'En attente de confirmation',    'en': 'Awaiting confirmation'});
  String get statusConfirmed       => _t({'fr': 'Commande confirmée !',          'en': 'Order confirmed!'});
  String get statusPreparing       => _t({'fr': 'En préparation 👨‍🍳',           'en': 'Preparing 👨‍🍳'});
  String get statusReady           => _t({'fr': 'Prête — livreur en route 🛵',  'en': 'Ready — driver on the way 🛵'});
  String get statusEnRoute         => _t({'fr': 'Livreur en route 🛵',          'en': 'Driver on the way 🛵'});
  String get statusDeliveredLabel  => _t({'fr': 'Livré ! Bon appétit 🎉',       'en': 'Delivered! Enjoy your meal 🎉'});
  String get yourAddress           => _t({'fr': 'Votre adresse',                 'en': 'Your address'});
  String get destination           => _t({'fr': 'Destination',                   'en': 'Destination'});
  String get driverLabel           => _t({'fr': 'Livreur',                       'en': 'Driver'});
  String get enRouteBike           => _t({'fr': 'En route 🛵',                  'en': 'On the way 🛵'});
  String get liveTracking          => _t({'fr': 'Suivi en direct',               'en': 'Live tracking'});
  String get yourDriver            => _t({'fr': 'Votre livreur',                 'en': 'Your driver'});
  String get vehicleLabel          => _t({'fr': '🏍️ Véhicule',                  'en': '🏍️ Vehicle'});
  String get colorLabel            => _t({'fr': '🎨 Couleur',                   'en': '🎨 Color'});
  String get plateLabel            => _t({'fr': '🔢 Matricule',                  'en': '🔢 License plate'});
  String get callDriver            => _t({'fr': 'Appeler',                       'en': 'Call'});
  String get messagingLabel        => _t({'fr': 'Messagerie',                    'en': 'Chat'});
  String get greatThanks           => _t({'fr': 'Super, merci !',                'en': 'Great, thank you!'});
  String get estimatedArrivalLabel => _t({'fr': 'Arrivée estimée :',             'en': 'Estimated arrival:'});
  String get paymentConfirmedCheck => _t({'fr': 'Paiement confirmé ✓',           'en': 'Payment confirmed ✓'});
  String get paymentPending        => _t({'fr': 'Paiement en attente',           'en': 'Payment pending'});
  String get foodLabel             => _t({'fr': 'Nourriture',                    'en': 'Food'});
  String get serviceLabel          => _t({'fr': 'Service',                       'en': 'Service'});
  String get restaurantLabel       => _t({'fr': 'Restaurant',                    'en': 'Restaurant'});
  String get mapLegendYou          => _t({'fr': 'Vous',                          'en': 'You'});
  String get whatsappNotAvailable  => _t({'fr': 'WhatsApp non disponible',       'en': 'WhatsApp not available'});
  String get deliveryLabel         => _t({'fr': 'Livraison',                     'en': 'Delivery'});

  // NOTIFICATIONS
  String get loginToSeeNotifications => _t({'fr': 'Connectez-vous pour voir vos notifications', 'en': 'Sign in to see your notifications'});
  String get noNotifications        => _t({'fr': 'Aucune notification',                         'en': 'No notifications'});
  String get noNotificationsHint    => _t({'fr': 'Vous recevrez des mises à jour\nsur vos commandes ici.', 'en': 'You will receive updates\non your orders here.'});
  String get followLink             => _t({'fr': 'Suivre le lien',                                         'en': 'Follow link'});
  String get markAllRead           => _t({'fr': 'Tout marquer lu',               'en': 'Mark all as read'});
  String get deleteAll             => _t({'fr': 'Tout supprimer',                'en': 'Delete all'});
  String get readNotifs            => _t({'fr': 'Lues',                          'en': 'Read'});
  String newNotifs(int count)      => _t({'fr': 'Nouvelles ($count)',            'en': 'New ($count)'});

  // HISTORIQUE COMMANDES
  String get loginToSeeOrders      => _t({'fr': 'Connectez-vous pour voir vos commandes', 'en': 'Sign in to see your orders'});
  String get deliveredTab          => _t({'fr': 'Livrées',                       'en': 'Delivered'});
  String get failedTab             => _t({'fr': 'Échouées',                      'en': 'Failed'});
  String get replaceCartTitle      => _t({'fr': 'Remplacer le panier ?',         'en': 'Replace cart?'});
  String get replaceCartMessage    => _t({'fr': 'Votre panier actuel sera remplacé par les articles de cette commande.', 'en': 'Your current cart will be replaced by the items from this order.'});
  String get continueBtn           => _t({'fr': 'Continuer',                     'en': 'Continue'});
  String get orderedItems          => _t({'fr': 'Articles commandés',            'en': 'Ordered items'});
  String get detailsLabel          => _t({'fr': 'Détails',                       'en': 'Details'});
  String get paymentMethodLabel    => _t({'fr': 'Paiement plats',                'en': 'Payment method'});
  String get transactionLabel      => _t({'fr': 'Transaction',                   'en': 'Transaction'});
  String get dateLabel             => _t({'fr': 'Date',                          'en': 'Date'});
  String get totalPaidApp          => _t({'fr': 'Total payé (App)',              'en': 'Total paid (App)'});
  String get deliveredOrdersOnly   => _t({'fr': 'Commandes livrées uniquement',  'en': 'Delivered orders only'});
  String get cardPayment           => _t({'fr': 'Carte bancaire',                'en': 'Credit card'});
  String get cashDelivery          => _t({'fr': 'Espèces à la livraison',        'en': 'Cash on delivery'});
  String get cancelReasonLabel     => _t({'fr': 'Raison d\'annulation',          'en': 'Cancellation reason'});
  String get retryOrder            => _t({'fr': 'Recommander',                   'en': 'Reorder'});
  String get cannotRetry           => _t({'fr': 'Impossible de retrouver les articles de cette commande.', 'en': 'Cannot find items from this order.'});
  String deliveriesCount(int total) => _t({'fr': '$total livraison${total > 1 ? "s" : ""} effectuée${total > 1 ? "s" : ""}', 'en': '$total deliver${total > 1 ? "ies" : "y"} completed'});
  String failedOrdersCount(int total) => _t({'fr': '$total commande${total > 1 ? "s" : ""} échouée${total > 1 ? "s" : ""}', 'en': '$total failed order${total > 1 ? "s" : ""}'});
  String get tapToRetry            => _t({'fr': 'Appuyez sur une commande pour relancer le paiement', 'en': 'Tap an order to retry payment'});
  String get retryPayment          => _t({'fr': 'Relancer le paiement',          'en': 'Retry payment'});
  String get retryLabel            => _t({'fr': 'Relancer',                      'en': 'Retry'});
  String get failedOrderBadge      => _t({'fr': 'Échouée',                       'en': 'Failed'});
  String get failedPaymentLabel    => _t({'fr': 'Paiement échoué',               'en': 'Payment failed'});
  String get noFailedOrders        => _t({'fr': 'Aucune commande échouée',       'en': 'No failed orders'});
  String get allPaymentsSuccess    => _t({'fr': 'Super ! Tous vos paiements ont réussi.', 'en': 'Great! All your payments succeeded.'});
  String get failedPaymentReason   => _t({'fr': 'Paiement Mobile Money échoué ou refusé', 'en': 'Mobile Money payment failed or rejected'});
  String get cancelledBeforePayment => _t({'fr': 'Commande annulée avant paiement', 'en': 'Order cancelled before payment'});
  String get dishesPriceLabel      => _t({'fr': 'Prix plats',                    'en': 'Dishes price'});
  String get commissionLabel       => _t({'fr': 'Commission (5%)',               'en': 'Commission (5%)'});
  String get deliveryCash          => _t({'fr': 'Livraison (payé cash)',          'en': 'Delivery (cash)'});
  String get deliveryApp           => _t({'fr': 'Livraison (payé App)',           'en': 'Delivery (App)'});
  String get subtotalDishes        => _t({'fr': 'Sous-total plats',              'en': 'Dishes subtotal'});
  String get itemsLabel            => _t({'fr': 'Articles',                      'en': 'Items'});
  String get statusDeliveredBadge  => _t({'fr': 'Livré ✓',                      'en': 'Delivered ✓'});
  String get statusEnRouteBadge    => _t({'fr': 'En route 🛵',                   'en': 'On the way 🛵'});
  String get statusConfirmedBadge  => _t({'fr': 'Confirmée',                    'en': 'Confirmed'});
  String get statusPendingBadge    => _t({'fr': 'En attente',                    'en': 'Pending'});
  String get deliveredBadge        => _t({'fr': 'Livré',                         'en': 'Delivered'});

  // PANIER — onglets & états
  String get favorites             => _t({'fr': 'Favoris',                        'en': 'Favorites'});
  String get history               => _t({'fr': 'Historique',                     'en': 'History'});
  String get noFavorites           => _t({'fr': 'Aucun favori',                   'en': 'No favorites'});
  String get addFavoritesHint      => _t({'fr': 'Appuyez sur ❤️ sur un restaurant\npour l\'ajouter ici', 'en': 'Tap ❤️ on a restaurant\nto add it here'});
  String get restaurantsNotFound   => _t({'fr': 'Restaurants introuvables',       'en': 'Restaurants not found'});
  String get deleteLabel           => _t({'fr': 'Supprimer',                      'en': 'Delete'});
  String get emptyCartTitle        => _t({'fr': 'Votre panier est vide',          'en': 'Your cart is empty'});
  String get emptyCartSub          => _t({'fr': 'Ajoutez des plats depuis un restaurant !', 'en': 'Add dishes from a restaurant!'});
  String get browseRestaurants     => _t({'fr': 'Parcourir les restaurants',      'en': 'Browse restaurants'});
  String get orderSummary          => _t({'fr': 'Récapitulatif',                  'en': 'Summary'});
  String get promoCodeLabel        => _t({'fr': 'Code promo',                     'en': 'Promo code'});
  String get applyCode             => _t({'fr': 'Appliquer',                      'en': 'Apply'});
  String get discount              => _t({'fr': 'Réduction',                      'en': 'Discount'});
  String get subtotal              => _t({'fr': 'Sous-total',                     'en': 'Subtotal'});
  String get chooseAddress         => _t({'fr': 'Choisir une adresse',            'en': 'Choose an address'});
  String get orderBtn              => _t({'fr': 'Commander',                      'en': 'Order'});

  // CONNEXION
  String get signIn                => _t({'fr': 'Connexion',                      'en': 'Sign in'});
  String get signUp                => _t({'fr': 'Inscription',                    'en': 'Sign up'});
  String get email                 => _t({'fr': 'Email',                          'en': 'Email'});
  String get password              => _t({'fr': 'Mot de passe',                   'en': 'Password'});
  String get fullName              => _t({'fr': 'Nom complet',                    'en': 'Full name'});
  String get phone                 => _t({'fr': 'Téléphone',                      'en': 'Phone'});
  String get confirmPassword       => _t({'fr': 'Confirmer le mot de passe',      'en': 'Confirm password'});
  String get forgotPassword        => _t({'fr': 'Mot de passe oublié ?',          'en': 'Forgot password?'});
  String get orContinueWith        => _t({'fr': 'Ou continuer avec',              'en': 'Or continue with'});
  String get continueWithGoogle    => _t({'fr': 'Continuer avec Google',          'en': 'Continue with Google'});
  String get noAccount             => _t({'fr': 'Pas encore de compte ?',         'en': 'No account yet?'});
  String get alreadyAccount        => _t({'fr': 'Déjà un compte ?',              'en': 'Already have an account?'});
  String get invalidEmail          => _t({'fr': 'Email invalide',                 'en': 'Invalid email'});
  String get minChars              => _t({'fr': 'Minimum 6 caractères',           'en': 'Minimum 6 characters'});
  String get passwordsMismatch     => _t({'fr': 'Les mots de passe ne correspondent pas', 'en': 'Passwords do not match'});
  String get nameRequired          => _t({'fr': 'Nom requis',                     'en': 'Name required'});
  String get phoneRequired         => _t({'fr': 'Téléphone requis (ex: 01234567)', 'en': 'Phone required (e.g. 01234567)'});
  String get resetEmailSent        => _t({'fr': 'Email de réinitialisation envoyé', 'en': 'Reset email sent'});

  // CONNEXION — boutons & messages
  String get signInBtn             => _t({'fr': 'Se connecter',                   'en': 'Sign in'});
  String get createAccount         => _t({'fr': 'Créer mon compte',               'en': 'Create account'});
  String get welcome               => _t({'fr': 'Bienvenue !',                    'en': 'Welcome!'});
  String get accountCreated        => _t({'fr': 'Compte créé ! Bienvenue',        'en': 'Account created! Welcome'});
  String get accessDenied          => _t({'fr': 'Accès refusé',                   'en': 'Access denied'});
  String get understood            => _t({'fr': 'Compris',                        'en': 'Got it'});
  String get noAccountEmail        => _t({'fr': 'Aucun compte avec cet email',    'en': 'No account with this email'});
  String get wrongPassword         => _t({'fr': 'Mot de passe incorrect',         'en': 'Wrong password'});
  String get tooManyAttempts       => _t({'fr': 'Trop de tentatives. Réessayez plus tard.', 'en': 'Too many attempts. Try again later.'});
  String get networkError          => _t({'fr': 'Erreur réseau.',                 'en': 'Network error.'});
  String get emailAlreadyUsed      => _t({'fr': 'Cet email est déjà utilisé',     'en': 'This email is already in use'});
  String get weakPassword          => _t({'fr': 'Mot de passe trop faible',       'en': 'Password too weak'});
  String get registrationError     => _t({'fr': 'Erreur lors de l\'inscription.', 'en': 'Registration error.'});
  String get connectedWithGoogle   => _t({'fr': 'Connecté avec Google',           'en': 'Connected with Google'});
  String get googleSignInError     => _t({'fr': 'Erreur Google Sign-In',          'en': 'Google Sign-In error'});
  String get phoneLabel            => _t({'fr': 'Numéro de téléphone',            'en': 'Phone number'});
  String get nameTooShort          => _t({'fr': 'Nom trop court (minimum 2 lettres)', 'en': 'Name too short (minimum 2 letters)'});
  String get nameLettersOnly       => _t({'fr': 'Le nom ne doit contenir que des lettres', 'en': 'Name must contain only letters'});
  String get phoneDigits           => _t({'fr': 'Entrez les 8 chiffres après le 01', 'en': 'Enter the 8 digits after 01'});
  String get passwordTooShort      => _t({'fr': 'Trop court — minimum 6 caractères', 'en': 'Too short — minimum 6 characters'});
  String get passwordNeedsDigit    => _t({'fr': 'Doit contenir au moins un chiffre', 'en': 'Must contain at least one digit'});
  String get resetEmailForEntry    => _t({'fr': 'Entrez votre email pour réinitialiser', 'en': 'Enter your email to reset'});
  String get resetLinkSent         => _t({'fr': 'Lien de réinitialisation envoyé par email !', 'en': 'Reset link sent by email!'});
  String get resetEmailError       => _t({'fr': 'Erreur : Impossible d\'envoyer l\'email.', 'en': 'Error: Unable to send the email.'});
  String get roleRestaurantError   => _t({'fr': 'Ce compte est réservé à l\'app Restaurant.\nTéléchargez AlloFoods Restaurant.', 'en': 'This account is for the Restaurant app.\nDownload AlloFoods Restaurant.'});
  String get roleDriverError       => _t({'fr': 'Ce compte est réservé à l\'app Livreur.\nTéléchargez AlloFoods Livreur.', 'en': 'This account is for the Driver app.\nDownload AlloFoods Driver.'});
  String get roleAdminError        => _t({'fr': 'Accès administrateur non autorisé ici.', 'en': 'Admin access not allowed here.'});
  String get roleUnauthorizedError => _t({'fr': 'Compte non autorisé dans cette application.', 'en': 'Account not authorized in this application.'});

  // PANIER — états vides & historique
  String get noDeliveredOrders     => _t({'fr': 'Aucune commande livrée',         'en': 'No delivered orders'});
  String get deliveredOrdersHint   => _t({'fr': 'Vos commandes livrées apparaîtront ici.', 'en': 'Your delivered orders will appear here.'});

  // RESTAURANT
  // PLAT DETAIL
  String get dishUnavailable       => _t({'fr': 'Plat indisponible',             'en': 'Dish unavailable'});
  String get chooseSingleOption    => _t({'fr': 'Choisissez 1 option',           'en': 'Choose 1 option'});
  String get instructions          => _t({'fr': 'Instructions',                  'en': 'Instructions'});
  String get addInstructionsHint   => _t({'fr': 'Ajouter des instructions pour le marchand (optionnel)', 'en': 'Add instructions for the merchant (optional)'});
  String addedToCart(String name)  => _t({'fr': '$name ajouté au panier',        'en': '$name added to cart'});
  String addToCartPrice(int price) => _t({'fr': 'Ajouter au panier  •  $price F', 'en': 'Add to cart  •  $price F'});
  String upToChoices(int n)        => _t({'fr': 'Jusqu\'à $n choix',             'en': 'Up to $n choices'});

  String get open                  => _t({'fr': 'Ouvert',                         'en': 'Open'});
  String get closed                => _t({'fr': 'Fermé',                          'en': 'Closed'});
  String get addToCart             => _t({'fr': 'Ajouter au panier',              'en': 'Add to cart'});
  String get menu                  => _t({'fr': 'Menu',                           'en': 'Menu'});
  String get reviews               => _t({'fr': 'Avis',                           'en': 'Reviews'});
  String get noReviews             => _t({'fr': 'Aucun avis pour l\'instant',     'en': 'No reviews yet'});
  String get writeReview           => _t({'fr': 'Laisser un avis',                'en': 'Write a review'});
  String get minOrder              => _t({'fr': 'Commande minimum',               'en': 'Minimum order'});
  String get deliveryTime          => _t({'fr': 'Livraison estimée',              'en': 'Estimated delivery'});

  // RÉCAP & PAIEMENT
  String get orderRecap            => _t({'fr': 'Récapitulatif de commande',      'en': 'Order summary'});
  String get recap                 => _t({'fr': 'Récapitulatif',                  'en': 'Summary'});
  String get yourItems             => _t({'fr': 'Vos articles',                   'en': 'Your items'});
  String get amountDetail          => _t({'fr': 'Détail du montant',              'en': 'Amount breakdown'});
  String get serviceFeeFive        => _t({'fr': 'Frais de service allofoods (5%)', 'en': 'AlloFoods service fee (5%)'});
  String get orderTotal            => _t({'fr': 'Total commande',                 'en': 'Order total'});
  String get viaAllofoods          => _t({'fr': 'via AlloFoods',                  'en': 'via AlloFoods'});
  String get cash                  => _t({'fr': 'Cash',                           'en': 'Cash'});
  String get toDriver              => _t({'fr': 'au livreur',                     'en': 'to driver'});
  String get debitedViaApp         => _t({'fr': 'Débité via AlloFoods',           'en': 'Charged via AlloFoods'});
  String get toGiveToDriver        => _t({'fr': 'À remettre au livreur',          'en': 'To give to driver'});
  String get securedPayment        => _t({'fr': 'Paiement sécurisé par AlloFoods', 'en': 'Secured payment by AlloFoods'});
  String get invalidPromoCode      => _t({'fr': 'Code promo invalide.',            'en': 'Invalid promo code.'});
  String get promoCodeInactive     => _t({'fr': 'Ce code promo n\'est plus actif.', 'en': 'This promo code is no longer active.'});
  String get promoCodeExpired      => _t({'fr': 'Ce code promo a expiré.',         'en': 'This promo code has expired.'});
  String get promoCodeLimitReached => _t({'fr': 'Ce code promo a atteint sa limite d\'utilisation.', 'en': 'This promo code has reached its usage limit.'});
  String get promoCodeAlreadyUsed  => _t({'fr': 'Vous avez déjà utilisé ce code promo.', 'en': 'You have already used this promo code.'});
  String get promoCheckError       => _t({'fr': 'Erreur lors de la vérification du code.', 'en': 'Error checking the code.'});
  String get firestoreAccessDenied => _t({'fr': 'Accès refusé par Firestore. Vérifiez les règles de sécurité.', 'en': 'Access denied by Firestore. Check security rules.'});
  String get noConnection          => _t({'fr': 'Pas de connexion. Vérifiez votre réseau.', 'en': 'No connection. Check your network.'});
  String promoDiscountApplied(int d) => _t({'fr': '− $d FCFA appliqués',          'en': '− $d FCFA applied'});
  String minOrderRequired(int min)   => _t({'fr': 'Commande minimum : $min FCFA pour ce code.', 'en': 'Minimum order: $min FCFA for this code.'});
  String payAmount(int amount)       => _t({'fr': 'Payer $amount FCFA',            'en': 'Pay $amount FCFA'});
  String itemCount(int n)            => _t({'fr': '$n article${n > 1 ? "s" : ""}', 'en': '$n item${n > 1 ? "s" : ""}'});
  String deliveryFeeKm(double km)    => _t({'fr': 'Frais de livraison (${km.toStringAsFixed(1)} km)', 'en': 'Delivery fee (${km.toStringAsFixed(1)} km)'});
  String get cashDeliveryNoticePrefix => _t({'fr': 'Vous paierez ',                 'en': 'You will pay '});
  String get cashDeliveryNoticeSuffix => _t({'fr': ' en espèces au livreur à la réception.', 'en': ' in cash to the driver upon delivery.'});
  String get deliveryAddress       => _t({'fr': 'Adresse de livraison',           'en': 'Delivery address'});
  String get deliveryNote          => _t({'fr': 'Instructions pour le livreur',   'en': 'Delivery instructions'});
  String get deliveryNotePlaceholder => _t({'fr': 'Ex: Bâtiment A, code d\'entrée 1234', 'en': 'E.g. Building A, entry code 1234'});
  String get payOnline             => _t({'fr': 'Payer en ligne',                 'en': 'Pay online'});
  String get payCash               => _t({'fr': 'Payer en cash',                  'en': 'Pay cash'});
  String get noAddressSelected     => _t({'fr': 'Aucune adresse sélectionnée',    'en': 'No address selected'});
  String get selectAddress         => _t({'fr': 'Sélectionner une adresse',       'en': 'Select an address'});
  String get confirmOrder          => _t({'fr': 'Confirmer la commande',          'en': 'Confirm order'});
  String get processing            => _t({'fr': 'Traitement en cours...',         'en': 'Processing...'});

  // PROFIL
  String get editPhotoHint         => _t({'fr': 'Modifier la photo',              'en': 'Change photo'});
  String get memberSince           => _t({'fr': 'Membre depuis',                  'en': 'Member since'});
  String get memberCode            => _t({'fr': 'Code membre',                    'en': 'Member code'});
  String get nameCannotBeEmpty     => _t({'fr': 'Le nom ne peut pas être vide',   'en': 'Name cannot be empty'});
  String get profileUpdated        => _t({'fr': 'Profil mis à jour ✅',           'en': 'Profile updated ✅'});
  String get updateError           => _t({'fr': 'Erreur de mise à jour',          'en': 'Update error'});
  String get photoUpdated          => _t({'fr': 'Photo mise à jour',              'en': 'Photo updated'});
  String get photoUploadError      => _t({'fr': 'Erreur de chargement de photo',  'en': 'Photo upload error'});
  String get deletePhotoTitle      => _t({'fr': 'Supprimer la photo ?',           'en': 'Delete photo?'});
  String get irreversibleAction    => _t({'fr': 'Cette action est irréversible.', 'en': 'This action is irreversible.'});
  String get photoDeleted          => _t({'fr': 'Photo supprimée',                'en': 'Photo deleted'});
  String get profilePhoto          => _t({'fr': 'Photo de profil',                'en': 'Profile photo'});
  String get chooseFromGallery     => _t({'fr': 'Choisir depuis la galerie',      'en': 'Choose from gallery'});
  String get takePhoto             => _t({'fr': 'Prendre une photo',              'en': 'Take a photo'});
  String get deletePhoto           => _t({'fr': 'Supprimer la photo',             'en': 'Delete photo'});
  String get myAccount             => _t({'fr': 'Mon compte',                     'en': 'My account'});
  String get settingsSecurity      => _t({'fr': 'Paramètres & Sécurité',          'en': 'Settings & Security'});
  String get userFallback          => _t({'fr': 'Utilisateur',                    'en': 'User'});
  String get loyaltyProgram        => _t({'fr': 'Programme Fidélité',             'en': 'Loyalty Program'});
  String get changeMyProfile       => _t({'fr': 'Changer mon profil',             'en': 'Edit my profile'});
  String pointsAccumulated(int n)  => _t({'fr': '$n points accumulés',            'en': '$n points accumulated'});

  // CHAT
  // FEDAPAY CHECKOUT
  String get paymentDeclined       => _t({'fr': 'Paiement refusé ou annulé.',    'en': 'Payment declined or cancelled.'});
  String get verificationInProgress => _t({'fr': 'Vérification en cours',        'en': 'Verification in progress'});
  String get paymentPendingConfirm => _t({'fr': 'Paiement en attente — confirmez sur votre téléphone.', 'en': 'Payment pending — confirm on your phone.'});
  String get verificationError     => _t({'fr': 'Erreur vérification. Réessayez.', 'en': 'Verification error. Try again.'});
  String get paymentCancelledMsg   => _t({'fr': 'Paiement annulé.',              'en': 'Payment cancelled.'});
  String get verifyPayment         => _t({'fr': 'J\'ai confirmé le paiement',    'en': 'I confirmed the payment'});
  String get verifying             => _t({'fr': 'Vérification',                  'en': 'Verifying'});
  String get emptyPage             => _t({'fr': 'Page vide ?',                   'en': 'Empty page?'});
  String get openInBrowser         => _t({'fr': 'Ouvrir dans le navigateur',     'en': 'Open in browser'});
  String statusRetry(String s)     => _t({'fr': 'Statut : $s. Réessayez dans quelques instants.', 'en': 'Status: $s. Retry in a moment.'});

  // CHAT
  String get chatWithDriver        => _t({'fr': 'Chat avec le livreur',           'en': 'Chat with driver'});
  String get typeMessage           => _t({'fr': 'Écrire un message...',           'en': 'Type a message...'});
  String get send                  => _t({'fr': 'Envoyer',                        'en': 'Send'});
  String get orderNumber           => _t({'fr': 'Commande',                       'en': 'Order'});
  String get driverOnline          => _t({'fr': 'En ligne',                       'en': 'Online'});
  String get sendMessageToDriver   => _t({'fr': 'Envoyez un message à votre livreur', 'en': 'Send a message to your driver'});
  String get chatExampleHint       => _t({'fr': 'Ex: sonnez à la grille',         'en': 'E.g. ring the gate bell'});
  String get messageToDriverHint   => _t({'fr': 'Message au livreur...',          'en': 'Message to driver...'});
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'yo', 'fo'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
