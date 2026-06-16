// lib/services/local_notification_service.dart
// Affichage des notifications locales (foreground FCM + système).
// Utilisé aussi bien pour les commandes que les campagnes promotionnelles.

import 'dart:io';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LocalNotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'allofoods_orders';
  static const _channelPromo = 'allofoods_promos';

  // Détails de base — SKU commandes (haute priorité)
  static const _baseDetails = AndroidNotificationDetails(
    _channelId,
    'Commandes allofoods',
    channelDescription:
        'Notifications en temps réel pour vos commandes et livraisons',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon',
    color: Color(0xFFFF9800),
    enableLights: true,
    ledColor: Color(0xFFFF9800),
    ledOnMs: 1000,
    ledOffMs: 500,
    enableVibration: true,
    playSound: true,
    visibility: NotificationVisibility.public,
  );

  static const _details = NotificationDetails(
    android: _baseDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    ),
  );

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    final androidImpl = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Canal haute priorité — commandes
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Commandes allofoods',
        description:
            'Notifications en temps réel pour vos commandes et livraisons',
        importance: Importance.max,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        ledColor: Color(0xFFFF9800),
      ),
    );

    // Canal promotions — campagnes Firebase Console
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelPromo,
        'Promotions allofoods',
        description: 'Offres spéciales et actualités allofoods',
        importance: Importance.high,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        ledColor: Color(0xFFFF9800),
      ),
    );

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) {},
    );
  }

  // ── Notification simple (texte) ────────────────────────────────────────────

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    bool isPromo = false,
  }) async {
    if (title.isEmpty && body.isEmpty) return;
    final details = isPromo
        ? NotificationDetails(
            android: AndroidNotificationDetails(
              _channelPromo,
              'Promotions allofoods',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              color: const Color(0xFFFF9800),
              enableLights: true,
              enableVibration: true,
              playSound: true,
              visibility: NotificationVisibility.public,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
            ),
          )
        : _details;

    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ── Notification avec image (campagnes Firebase Console) ──────────────────
  // Télécharge l'image et l'affiche en "grand visuel" (BigPicture style Android,
  // ou dans le corps de la notification sur iOS).

  static Future<void> showRich({
    required int id,
    required String title,
    required String body,
    String? imageUrl,
    bool isPromo = false,
  }) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return show(id: id, title: title, body: body, isPromo: isPromo);
    }

    try {
      // Télécharger l'image vers un fichier temporaire
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final tmpDir = await getTemporaryDirectory();
        final filePath = '${tmpDir.path}/notif_img_${id.abs()}.jpg';
        await File(filePath).writeAsBytes(response.bodyBytes);

        final channelId = isPromo ? _channelPromo : _channelId;
        final channelName = isPromo ? 'Promotions allofoods' : 'Commandes allofoods';

        await plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              color: const Color(0xFFFF9800),
              enableLights: true,
              enableVibration: true,
              playSound: true,
              visibility: NotificationVisibility.public,
              // Grand visuel — affiché quand l'utilisateur déroule la notification
              styleInformation: BigPictureStyleInformation(
                FilePathAndroidBitmap(filePath),
                largeIcon: FilePathAndroidBitmap(filePath),
                contentTitle: title,
                summaryText: body,
                hideExpandedLargeIcon: false,
              ),
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
              attachments: [
                DarwinNotificationAttachment(filePath),
              ],
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Image non téléchargeable → notification texte simple
    }

    await show(id: id, title: title, body: body, isPromo: isPromo);
  }

  // ── Notifications paiement ─────────────────────────────────────────────────

  static Future<void> showUssdPaymentSent(
      {required String phoneNumber}) async {
    await show(
      id: 9001,
      title: 'Demande de paiement Mobile Money envoyée',
      body:
          'Vérifiez votre téléphone ($phoneNumber) et confirmez avec votre PIN.',
    );
  }

  static Future<void> showPaymentConfirmed(
      {required String restaurantName}) async {
    await show(
      id: 9002,
      title: 'Paiement confirmé !',
      body: 'Votre commande chez $restaurantName est en cours de traitement.',
    );
  }
}
