// lib/main.dart é allofoods + FCM intégré
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:flutter_application_2/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'firebase_options.dart';
import 'config/env_config.dart';
import 'models/cart_model.dart';
import 'models/delivery_model.dart';
import 'pages/homepage.dart';
import 'pages/restaurantpage.dart';
import 'pages/PanierPage.dart';
import 'pages/AdressesPage.dart';
import 'pages/ProfilPage.dart';
import 'pages/LoginPage.dart';
import 'pages/TermsPage.dart';
import 'providers/language_provider.dart';
import 'providers/pending_order_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/active_order_notifier.dart';
import 'pages/NotificationsPage.dart';
import 'pages/SettingsScreen.dart';
import 'pages/TrackingPage.dart';
import 'pages/WaitingPage.dart';
import 'pages/restaurant_detail_page.dart';
import 'models/restaurant_model.dart';
import 'widgets/allofoods_app_bar.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
final _appNavKey = GlobalKey<NavigatorState>();

// Handler FCM background — DOIT être top-level, exécuté quand app est fermée/arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.initialize();

  final notif = message.notification;
  final type = message.data['type'] as String? ?? '';
  final title = notif?.title ?? message.data['title'] as String? ?? 'allofoods';
  final body = notif?.body ?? message.data['body'] as String? ?? '';

  // Messages data-only → afficher manuellement (les messages avec notif payload
  // sont déjà affichés automatiquement par le système quand l'app est en arrière-plan)
  if (notif == null && body.isNotEmpty) {
    final imageUrl = message.data['image'] as String?;
    await LocalNotificationService.showRich(
      id: message.hashCode,
      title: title,
      body: body,
      imageUrl: imageUrl,
      isPromo: type != 'order_status' && type != 'order',
    );
  }

  // Enregistrer dans l'historique Firestore (sauf order_status déjà écrit par Cloud Function)
  // Promo, annonces, paiements → écrire ici
  if (type != 'order_status' && type != 'order' && title.isNotEmpty) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'title': title,
          'message': body,
          'type': type.isEmpty ? 'info' : type,
          'isRead': false,
          'orderId': message.data['orderId'] ?? '',
          'restaurantId': message.data['restaurantId'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }
}

Future<void> _createAndroidNotificationChannel() async {
  await LocalNotificationService.initialize();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

// MAIN
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix crash SIGABRT sur Android < 33 (SurfaceProducer + ImageReader fence non supporté)
  // Hybrid Composition évite le path ImageReader entièrement
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    mapsImpl.useAndroidViewSurface = true;
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Capture toutes les erreurs Flutter pour éviter les crashs silencieux (ANR)
  FlutterError.onError =
      (details) => debugPrint('[Flutter Error] ${details.exceptionAsString()}');

  await initializeDateFormatting('fr_FR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: '.env');

  // Initialiser Supabase (storage photos)
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Persistance Firestore offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Enregistrer le handler FCM background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Créer le canal Android avec importance MAX
  await _createAndroidNotificationChannel();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => PendingOrderProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ActiveOrderNotifier()),
      ],
      child: const allofoodsApp(),
    ),
  );
}

// APP
class allofoodsApp extends StatelessWidget {
  const allofoodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'allofoods',
      debugShowCheckedModeBanner: false,
      locale: lang.locale,
      themeMode: theme.mode,
      supportedLocales:
          LanguageProvider.supported.keys.map((code) => Locale(code)).toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Poppins',
        // Transitions style iOS sur Android et iOS
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.orange,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.orange,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
      navigatorKey: _appNavKey,
      builder: (context, child) => Stack(
        children: [
          MobileWebWrapper(child: child!),
          const Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Center(child: _ActiveOrderFAB()),
          ),
        ],
      ),
      home: const AuthGate(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/notifications': (_) => const NotificationsPage(),
      },
    );
  }
}

// AUTH GATE  avec initialisation FCM
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _watchedUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white);
        }
        final user = snapshot.data;
        if (user != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(backgroundColor: Colors.white);
              }
              final data =
                  userSnap.data?.data() as Map<String, dynamic>?;
              if (data == null || data['termsAccepted'] != true) {
                return TermsAcceptancePage(uid: user.uid);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _watchedUid == user.uid) return;
                _watchedUid = user.uid;
                context.read<ActiveOrderNotifier>().startWatching(user.uid);
                FcmService.initialize();
              });
              return const MainScaffold();
            },
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _watchedUid == null) return;
          _watchedUid = null;
          context.read<ActiveOrderNotifier>().stopWatching();
        });
        return const LoginPage();
      },
    );
  }
}

// MAIN SCAFFOLD é avec écoute FCM foreground
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  late final PageController _pageCtrl;

  late final List<Widget> _pages = [
    const Homepage(),
    const RestaurantPage(),
    const PanierPage(),
    const AdressesPage(),
    const ProfilPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _setupFcmHandlers();
    _checkInitialMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkActiveOrder());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    setState(() => _index = i);
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Redirige vers TrackingPage si commande active
  Future<void> _checkActiveOrder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('clientUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty || !mounted) return;
      final doc = snap.docs.first;
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      const terminalStatuses = [
        'delivered',
        'cancelled',
        'cancelled_by_restaurant',
        'awaiting_payment', // paiement non encore confirmé — PaiementPage gère
      ];
      if (terminalStatuses.contains(status) || status.isEmpty) return;

      // Commandes payées en attente de préparation/livraison ? WaitingPage
      const waitingStatuses = [
        'paid',
        'preparing',
        'ready_for_pickup'
      ];
      if (waitingStatuses.contains(status)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingPage(
              orderId: doc.id,
              totalAmount: (data['totalAmount'] as num?)?.toInt() ?? 0,
              restaurantName: data['restaurantName'] as String? ?? '',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingPage(
            orderId: doc.id,
            orderAmount: (data['totalAmount'] as num?)?.toInt() ?? 0,
            restaurantName: data['restaurantName'] as String? ?? '',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ActiveOrder] $e');
    }
  }

  // Messages reçus quand app est au PREMIER PLAN
  void _setupFcmHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM FG] ${message.notification?.title}');

      final notif = message.notification;
      final type = message.data['type'] as String? ?? '';

      // Bannière système + son + vibration (Android / iOS)
      // showRich() télécharge et affiche l'image si la campagne en contient une.
      if (notif != null) {
        final imageUrl = notif.android?.imageUrl ??
            notif.apple?.imageUrl ??
            message.data['image'] as String?;
        final isPromo = type == 'promo' || type == 'info' || type.isEmpty;
        LocalNotificationService.showRich(
          id: message.hashCode,
          title: notif.title ?? '',
          body: notif.body ?? '',
          imageUrl: imageUrl,
          isPromo: isPromo,
        );
      }

      // Enregistrer dans l'historique Firestore (sauf order_status déjà écrit par Cloud Function)
      if (notif != null && type != 'order_status' && type != 'order') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .add({
            'title': notif.title ?? '',
            'message': notif.body ?? '',
            'type': type.isEmpty ? 'info' : type,
            'isRead': false,
            'orderId': message.data['orderId'] ?? '',
            'restaurantId': message.data['restaurantId'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (notif == null || !mounted) return;

      // Incrémenter le badge notifications
      context.read<NotificationProvider>().increment();

      // SnackBar in-app avec bouton "Voir" qui redirige intelligemment
      final msgData = message.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.notifications, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notif.title != null)
                      Text(notif.title!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    if (notif.body != null)
                      Text(notif.body!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ]),
            ),
          ]),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Voir',
            textColor: Colors.white,
            onPressed: () => _handleNotificationTap(msgData),
          ),
        ),
      );
    });

    // App ouverte en cliquant sur une notification (arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Tap BG] ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  // App lancée depuis une notification (terminée)
  Future<void> _checkInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      debugPrint('[FCM Initial] ${message.data}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(message.data);
      });
    }
  }

  // ── Routeur principal de deep-linking ──────────────────────────────────────

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final orderId = data['orderId'] as String? ?? '';
    final restaurantId = data['restaurantId'] as String? ?? '';

    switch (type) {
      case 'order_status':
      case 'order':
      case 'payment_success':
        if (orderId.isNotEmpty) {
          _navigateToOrder(orderId);
        } else {
          Navigator.pushNamed(context, '/notifications');
        }
        break;
      case 'restaurant':
      case 'promo':
        if (restaurantId.isNotEmpty) {
          _navigateToRestaurant(restaurantId);
        } else {
          _goToPage(1); // onglet Restaurants
        }
        break;
      case 'monthly_payout':
        _goToPage(4); // onglet Profil
        break;
      default:
        Navigator.pushNamed(context, '/notifications');
    }
  }

  // Récupère la commande et pousse WaitingPage ou TrackingPage selon le statut
  Future<void> _navigateToOrder(String orderId) async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      if (!mounted || !doc.exists) return;
      final d = doc.data()!;
      final status = d['status'] as String? ?? '';
      final amount = (d['totalAmount'] as num?)?.toInt() ?? 0;
      final restName = d['restaurantName'] as String? ?? '';

      const waitingStatuses = {'paid', 'preparing', 'ready_for_pickup'};
      if (waitingStatuses.contains(status)) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => WaitingPage(
            orderId: orderId,
            totalAmount: amount,
            restaurantName: restName,
          ),
        ));
      } else if (status.isNotEmpty &&
          status != 'delivered' &&
          status != 'cancelled' &&
          status != 'cancelled_by_restaurant') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TrackingPage(
            orderId: orderId,
            orderAmount: amount,
            restaurantName: restName,
          ),
        ));
      } else {
        // Commande terminée → historique notifications
        Navigator.pushNamed(context, '/notifications');
      }
    } catch (e) {
      debugPrint('[NotifTap] erreur navigation commande: $e');
      if (mounted) Navigator.pushNamed(context, '/notifications');
    }
  }

  // Récupère le restaurant et pousse RestaurantDetailPage
  Future<void> _navigateToRestaurant(String restaurantId) async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      if (!mounted || !doc.exists) {
        _goToPage(1);
        return;
      }
      final data = <String, dynamic>{...doc.data()!, 'id': doc.id};
      final restaurant = Restaurant.fromJson(data);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => RestaurantDetailPage(restaurant: restaurant),
      ));
    } catch (e) {
      debugPrint('[NotifTap] erreur navigation restaurant: $e');
      if (mounted) _goToPage(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final t = AppLocalizations.of(context);
    final titles = ['allofoods', t.restaurants, t.cart, t.address, t.profile];
    return Scaffold(
      appBar: allofoodsAppBar(title: titles[_index]),
      body: PageView(
        controller: _pageCtrl,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goToPage,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF1CE9B),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.brown,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: t.home),
          BottomNavigationBarItem(
              icon: const Icon(Icons.restaurant_menu_outlined),
              activeIcon: const Icon(Icons.restaurant_menu),
              label: t.restaurants),
          BottomNavigationBarItem(
              icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  child: const Icon(Icons.shopping_cart_outlined)),
              activeIcon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  child: const Icon(Icons.shopping_cart)),
              label: t.cart),
          BottomNavigationBarItem(
              icon: const Icon(Icons.location_on_outlined),
              activeIcon: const Icon(Icons.location_on),
              label: t.address),
          BottomNavigationBarItem(
              icon: const Icon(Icons.account_circle_outlined),
              activeIcon: const Icon(Icons.account_circle),
              label: t.profile),
        ],
      ),
    );
  }
}

// MOBILE WEB WRAPPER à identique à l'original
class MobileWebWrapper extends StatelessWidget {
  final Widget child;
  const MobileWebWrapper({super.key, required this.child});

  static const double _phoneWidth = 375.0;
  static const double _phoneRadius = 44.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    if (!isWeb) return child;

    final availH = size.height;
    const topBar = 30.0;
    const bottomBar = 24.0;
    const vertPadding = 40.0;
    final phoneHeight = availH - topBar - bottomBar - vertPadding;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0A00),
              Color(0xFF2D1200),
              Color(0xFF3D1F00),
              Color(0xFF1A0A00),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(children: [
          Center(
              child: Container(
            width: _phoneWidth + 60,
            height: phoneHeight + 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_phoneRadius + 10),
              boxShadow: [
                BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.25),
                    blurRadius: 80,
                    spreadRadius: 20)
              ],
            ),
          )),
          Positioned(
              top: 60,
              left: 80,
              child: _glowDot(8, Colors.orange.withValues(alpha: 0.6))),
          Positioned(
              top: 140,
              left: 40,
              child: _glowDot(5, Colors.orange.withValues(alpha: 0.4))),
          Positioned(
              top: 200,
              right: 100,
              child: _glowDot(6, Colors.orange.withValues(alpha: 0.5))),
          Positioned(
              bottom: 120,
              left: 60,
              child: _glowDot(10, Colors.orange.withValues(alpha: 0.3))),
          Positioned(
              bottom: 80,
              right: 80,
              child: _glowDot(7, Colors.orange.withValues(alpha: 0.4))),
          Positioned(
            top: 32,
            left: 36,
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2)
                      ]),
                  child: const Icon(Icons.fastfood,
                      color: Colors.white, size: 22)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('allofoods',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins')),
                Text('Cotonou, Bénin',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ]),
            ]),
          ),
          Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_phoneRadius)),
              child: Container(
                width: _phoneWidth,
                height: topBar,
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12), width: 1.5)),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Container(
                      width: 90,
                      height: 14,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8))),
                ]),
              ),
            ),
            Container(
              width: _phoneWidth,
              height: phoneHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                  right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                ),
              ),
              child: ClipRect(
                  child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(_phoneWidth, phoneHeight),
                  padding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: child,
              )),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_phoneRadius)),
              child: Container(
                width: _phoneWidth,
                height: bottomBar,
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12), width: 1.5)),
                child: Center(
                    child: Container(
                        width: 110,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3)))),
              ),
            ),
          ])),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
                child: Text('AlloFoods à Cotonou, Bénin',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        letterSpacing: 0.5))),
          ),
        ]),
      ),
    );
  }

  Widget _glowDot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color, blurRadius: size * 2, spreadRadius: 1)
            ]),
      );
}

// FLOATING ORDER BANNER
class _ActiveOrderFAB extends StatefulWidget {
  const _ActiveOrderFAB();
  @override
  State<_ActiveOrderFAB> createState() => _ActiveOrderFABState();
}

class _ActiveOrderFABState extends State<_ActiveOrderFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  static const _waitingStatuses = {
    'paid',
    'preparing',
    'ready_for_pickup'
  };

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.5,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _navigate(ActiveOrderNotifier n) {
    final orderId = n.orderId!;
    final amount = n.totalAmount;
    final rest = n.restaurantName ?? '';
    if (_waitingStatuses.contains(n.status)) {
      _appNavKey.currentState?.push(MaterialPageRoute(
        builder: (_) => WaitingPage(
          orderId: orderId,
          totalAmount: amount,
          restaurantName: rest,
        ),
      ));
    } else {
      _appNavKey.currentState?.push(MaterialPageRoute(
        builder: (_) => TrackingPage(
          orderId: orderId,
          orderAmount: amount,
          restaurantName: rest,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveOrderNotifier>(
      builder: (_, notifier, __) {
        final show = notifier.showBanner;
        return IgnorePointer(
          ignoring: !show,
          child: AnimatedSlide(
            offset: show ? Offset.zero : const Offset(0, 0.3),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: show ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              child: GestureDetector(
                onTap: () => _navigate(notifier),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade700, Colors.orange.shade500],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: _pulse.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.delivery_dining,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Suivi en cours...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (notifier.restaurantName != null)
                              Text(
                                notifier.restaurantName!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// SPLASH VIDéO é animation .webm plein écran
