// lib/services/api_service.dart
// ? 100% Firebase é storage photos via Supabase

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/storage_service.dart';

class ApiService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => _auth.currentUser?.uid;

  // AUTH

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      await Future.wait([
        _db.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'imageUrl': null,
          'role': 'client',
          'createdAt': FieldValue.serverTimestamp(),
        }),
        cred.user!.updateDisplayName(name),
      ]);
      return {'success': true, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'error': true, 'message': _authError(e.code)};
    } catch (e) {
      return {'error': true, 'message': 'Erreur réseau.'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return {'success': true, 'uid': cred.user!.uid};
    } on FirebaseAuthException catch (e) {
      return {'error': true, 'message': _authError(e.code)};
    } catch (e) {
      return {'error': true, 'message': 'Erreur réseau.'};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {'error': true, 'message': 'Non connecté'};
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return {'error': true, 'message': 'Profil introuvable'};
      return {'user': snap.data()!};
    } catch (e) {
      return {'error': true, 'message': 'Erreur réseau.'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    try {
      final uid = _uid;
      if (uid == null) return {'error': true, 'message': 'Non connecté'};
      final updates = <String, dynamic>{};
      if (data.containsKey('name')) updates['name'] = data['name'];
      if (data.containsKey('phone')) updates['phone'] = data['phone'];
      if (data.containsKey('imageUrl')) updates['imageUrl'] = data['imageUrl'];
      await _db.collection('users').doc(uid).update(updates);
      if (data.containsKey('name')) {
        await _auth.currentUser!.updateDisplayName(data['name']);
      }
      return {'success': true};
    } catch (e) {
      return {'error': true, 'message': 'Erreur mise à jour profil.'};
    }
  }

  static Future<void> logout() async => await _auth.signOut();

  static bool isLoggedIn() => _auth.currentUser != null;

  // RESTAURANTS é Firestore collection 'restaurants'

  static Future<List<dynamic>> getRestaurants({String? search}) async {
    try {
      Query query = _db.collection('restaurants');
      final snap = await query.get();
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'id': d.id, ...data};
      }).toList();
      // Filtre recherche cété client
      if (search != null && search.isNotEmpty) {
        final lower = search.toLowerCase();
        return list.where((r) {
          final name = (r['name'] as String? ?? '').toLowerCase();
          final style = (r['style'] as String? ?? '').toLowerCase();
          final tags = (r['tags'] as List? ?? [])
              .map((t) => t.toString().toLowerCase())
              .toList();
          return name.contains(lower) ||
              style.contains(lower) ||
              tags.any((t) => t.contains(lower));
        }).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getRestaurantById(String id) async {
    try {
      final snap = await _db.collection('restaurants').doc(id).get();
      if (!snap.exists) return {};
      return {'id': snap.id, ...snap.data()!};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getRestaurant(String id) =>
      getRestaurantById(id);

  // COMMANDES é Firestore collection 'orders'

  static Future<Map<String, dynamic>> createOrder({
    required String restaurantId,
    required String restaurantName,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    required double subtotal,
    required double deliveryFee,
    required double serviceFee,
    required double total,
    required double distanceKm,
    required String paymentMethod,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) return {'error': true, 'message': 'Non connecté'};
      final ref = await _db.collection('orders').add({
        'clientUid': uid,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'items': items,
        'deliveryAddress': deliveryAddress,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'serviceFee': serviceFee,
        'totalAmount': total,
        'distanceKm': distanceKm,
        'paymentMethod': paymentMethod,
        'status': 'pending',
        'driverLat': null,
        'driverLng': null,
        'driverName': '',
        'driverPhone': '',
        'estimatedArrival': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Notification
      await _db.collection('users').doc(uid).collection('notifications').add({
        'title': 'Commande rééu avec succès.',
        'message': 'Votre commande chez $restaurantName est enregistrée.',
        'type': 'order',
        'isRead': false,
        'orderId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'orderId': ref.id};
    } catch (e) {
      return {'error': true, 'message': 'Erreur création commande.'};
    }
  }

  static Future<List<dynamic>> getMyOrders() async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final snap = await _db
          .collection('orders')
          .where('clientUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getOrder(String id) async {
    try {
      final snap = await _db.collection('orders').doc(id).get();
      if (!snap.exists) return {};
      return {'id': snap.id, ...snap.data()!};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> rateOrder(
      String id, int rating, String comment) async {
    try {
      await _db.collection('orders').doc(id).update({
        'rating': rating,
        'comment': comment,
        'ratedAt': FieldValue.serverTimestamp(),
      });
      return {'success': true};
    } catch (e) {
      return {'error': true, 'message': 'Erreur notation.'};
    }
  }

  // PAIEMENTS é stockés dans la commande Firestore

  static Future<Map<String, dynamic>> savePayment({
    required String orderId,
    required double amount,
    required String method,
    required String operator,
    String? phoneNumber,
    String? kkiapayTransactionId,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'payment': {
          'amount': amount,
          'method': method,
          'operator': operator,
          'phoneNumber': phoneNumber,
          'kkiapayTransactionId': kkiapayTransactionId,
          'paidAt': FieldValue.serverTimestamp(),
        },
        'status': 'confirmed',
      });
      return {'success': true};
    } catch (e) {
      return {'error': true, 'message': 'Erreur sauvegarde paiement.'};
    }
  }

  static Future<List<dynamic>> getMyPayments() async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final snap = await _db
          .collection('orders')
          .where('clientUid', isEqualTo: uid)
          .where('payment', isNull: false)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .where((d) => d.data().containsKey('payment'))
          .map((d) => {
                'orderId': d.id,
                'restaurant': d.data()['restaurantName'],
                ...d.data()['payment'] as Map<String, dynamic>,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // PHOTO DE PROFIL é Supabase Storage

  static Future<Map<String, dynamic>> updateProfileImage(
      String base64Img) async {
    try {
      final uid = _uid;
      if (uid == null) return {'error': true, 'message': 'Non connecté'};

      final imageUrl = await StorageService.uploadBase64(
        base64Img,
        bucket: StorageService.bucketProfiles,
        fileName: '$uid.jpg',
      );
      if (imageUrl == null) {
        return {'error': true, 'message': 'Erreur upload photo.'};
      }

      await Future.wait([
        _db.collection('users').doc(uid).update({'imageUrl': imageUrl}),
        _auth.currentUser!.updatePhotoURL(imageUrl),
      ]);
      return {'success': true, 'imageUrl': imageUrl};
    } catch (e) {
      return {'error': true, 'message': 'Erreur upload photo.'};
    }
  }

  // Supprimer la photo de profil (remet null dans Firestore)
  static Future<Map<String, dynamic>> deleteProfileImage() async {
    try {
      final uid = _uid;
      if (uid == null) return {'error': true, 'message': 'Non connecté'};
      await Future.wait([
        _db.collection('users').doc(uid).update({'imageUrl': null}),
        _auth.currentUser!.updatePhotoURL(null),
      ]);
      return {'success': true};
    } catch (e) {
      return {'error': true, 'message': 'Erreur suppression photo.'};
    }
  }

  // NOTIFICATIONS é Firestore subcollection

  static Future<List<dynamic>> getNotifications() async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    try {
      final uid = _uid;
      if (uid == null) return 0;
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markNotificationsAsRead() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // HELPER é messages d'erreur Firebase en français
  static String _authError(String code) => switch (code) {
        'user-not-found' => 'Aucun compte avec cet email.',
        'wrong-password' => 'Mot de passe incorrect.',
        'email-already-in-use' => 'Cet email est déjà utilisé.',
        'weak-password' => 'Mot de passe trop faible (min 6 caractéres).',
        'invalid-email' => 'Adresse email invalide.',
        'user-disabled' => 'Ce compte a été désactivé.',
        'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
        'network-request-failed' => 'Erreur réseau. Vérifiez votre connexion.',
        _ => 'Erreur d\'authentification. Réessayez.',
      };
}
