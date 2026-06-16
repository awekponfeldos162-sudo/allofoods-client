import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/providers/active_order_notifier.dart';

void main() {
  late ActiveOrderNotifier notifier;

  setUp(() {
    notifier = ActiveOrderNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('ActiveOrderNotifier — état initial', () {
    test('aucune commande active au démarrage', () {
      expect(notifier.orderId, isNull);
      expect(notifier.status, isNull);
      expect(notifier.restaurantName, isNull);
      expect(notifier.totalAmount, equals(0));
      expect(notifier.isOrderPageOpen, isFalse);
    });

    test('showBanner = false au démarrage', () {
      expect(notifier.showBanner, isFalse);
    });
  });

  group('ActiveOrderNotifier — showBanner', () {
    test('showBanner false quand orderId est null', () {
      notifier.status = 'en_route';
      notifier.isOrderPageOpen = false;
      expect(notifier.showBanner, isFalse);
    });

    test('showBanner true pour tous les statuts bannerisés', () {
      const bannerStatuses = [
        'confirmed',
        'preparing',
        'ready',
        'ready_for_pickup',
        'en_route',
        'delivering',
      ];
      for (final s in bannerStatuses) {
        notifier.orderId = 'order_$s';
        notifier.status = s;
        notifier.isOrderPageOpen = false;
        expect(
          notifier.showBanner,
          isTrue,
          reason: 'showBanner devrait être true pour status="$s"',
        );
      }
    });

    test('showBanner false pour les statuts hors liste', () {
      const nonBannerStatuses = [
        'delivered',
        'cancelled',
        'awaiting_payment',
        'paid',
        'pending',
        '',
      ];
      for (final s in nonBannerStatuses) {
        notifier.orderId = 'order123';
        notifier.status = s;
        notifier.isOrderPageOpen = false;
        expect(
          notifier.showBanner,
          isFalse,
          reason: 'showBanner devrait être false pour status="$s"',
        );
      }
    });

    test('showBanner false quand isOrderPageOpen = true', () {
      notifier.orderId = 'order123';
      notifier.status = 'en_route';
      notifier.isOrderPageOpen = true;
      expect(notifier.showBanner, isFalse);
    });
  });

  group('ActiveOrderNotifier — setOrderPageOpen', () {
    test('setOrderPageOpen(true) met isOrderPageOpen à true', () {
      notifier.setOrderPageOpen(true);
      expect(notifier.isOrderPageOpen, isTrue);
    });

    test('setOrderPageOpen(false) met isOrderPageOpen à false', () {
      notifier.setOrderPageOpen(true);
      notifier.setOrderPageOpen(false);
      expect(notifier.isOrderPageOpen, isFalse);
    });

    test('setOrderPageOpen sans changement ne notifie pas', () {
      int count = 0;
      notifier.addListener(() => count++);

      notifier.setOrderPageOpen(false); // déjà false → pas de notif
      expect(count, equals(0));

      notifier.setOrderPageOpen(true); // changement → notif
      expect(count, equals(1));

      notifier.setOrderPageOpen(true); // même valeur → pas de notif
      expect(count, equals(1));
    });

    test('setOrderPageOpen(false) avec commande active → showBanner true', () {
      notifier.orderId = 'order123';
      notifier.status = 'preparing';
      notifier.setOrderPageOpen(true);
      expect(notifier.showBanner, isFalse);
      notifier.setOrderPageOpen(false);
      expect(notifier.showBanner, isTrue);
    });
  });

  group('ActiveOrderNotifier — notifications', () {
    test('modification directe des propriétés + setOrderPageOpen notifie', () {
      int count = 0;
      notifier.addListener(() => count++);

      notifier.setOrderPageOpen(true);
      expect(count, equals(1));
    });

    test('stopWatching appelle dispose sans erreur', () {
      // stopWatching appelle _clear() qui appelle notifyListeners()
      // Sans sub Firestore actif, cela doit fonctionner sans erreur
      expect(() => notifier.stopWatching(), returnsNormally);
      expect(notifier.orderId, isNull);
    });
  });
}
