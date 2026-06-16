// lib/repositories/user_repository.dart
// ? Repository pattern é fait le lien Firestore ? Firebase Auth ? Supabase Storage
// Responsabilité unique : opérations CRUD sur l'utilisateur

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/storage_service.dart';

class UserRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  // Charger le profil depuis Firestore
  Future<Map<String, dynamic>> loadProfile() async {
    if (uid == null) return {};

    final doc = await _db.collection('users').doc(uid).get();

    // Auto-création si document inexistant (1ère connexion Google/Social)
    if (!doc.exists) {
      final memberCode = _generateMemberCode();
      // Ne pas mettre FieldValue dans le map retourné
      await _db.collection('users').doc(uid).set({
        'uid': uid!,
        'name': currentUser?.displayName ?? '',
        'email': currentUser?.email ?? '',
        'phone': '',
        'imageUrl': currentUser?.photoURL,
        'role': 'client',
        'memberCode': memberCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Retourner un map propre sans FieldValue
      return {
        'uid': uid!,
        'name': currentUser?.displayName ?? '',
        'email': currentUser?.email ?? '',
        'phone': '',
        'imageUrl': currentUser?.photoURL,
        'role': 'client',
        'memberCode': memberCode,
      };
    }

    final data = Map<String, dynamic>.from(doc.data()!);

    // Génèrer un code membre si absent (migration anciens comptes)
    if (!data.containsKey('memberCode') || data['memberCode'] == null) {
      final code = _generateMemberCode();
      await _db.collection('users').doc(uid!).update({'memberCode': code});
      data['memberCode'] = code;
    }

    // Complèter avec Firebase Auth si champs vides dans Firestore
    if ((data['name'] as String?)?.isEmpty ?? true) {
      data['name'] = currentUser?.displayName ?? '';
    }
    if ((data['email'] as String?)?.isEmpty ?? true) {
      data['email'] = currentUser?.email ?? '';
    }
    if ((data['imageUrl'] as String?)?.isEmpty ?? true) {
      data['imageUrl'] = currentUser?.photoURL;
    }

    return data;
  }

  // Sauvegarder nom + téléphone
  Future<void> updateProfile({
    required String name,
    required String phone,
    required String email,
  }) async {
    if (uid == null) return;
    await Future.wait([
      _db.collection('users').doc(uid).update({
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
      }),
      currentUser!.updateDisplayName(name.trim()),
    ]);
  }

  // Upload photo + sync Firestore + Auth
  Future<String?> updatePhoto(Uint8List bytes) async {
    final url = await StorageService.uploadImage(bytes,
        bucket: StorageService.bucketProfiles);
    if (url == null || uid == null) return null;

    try {
      // Firestore update
      final docRef = _db.collection('users').doc(uid!);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({'imageUrl': url});
      } else {
        await docRef.set({'imageUrl': url}, SetOptions(merge: true));
      }
      // Firebase Auth photoURL
      await currentUser!.updatePhotoURL(url);
    } catch (e) {
      print('[UserRepository] updatePhoto Firestore error: \$e');
      // URL uploadée avec succès même si Firestore échoue
    }

    return url;
  }

  // Supprimer photo
  Future<void> deletePhoto() async {
    if (uid == null) return;
    await Future.wait([
      _db.collection('users').doc(uid!).update({'imageUrl': null}),
      currentUser!.updatePhotoURL(null),
    ]);
  }

  // Code membre format AF-2025-XXXX
  String _generateMemberCode() {
    final year = DateTime.now().year;
    final suffix = uid!.substring(0, 4).toUpperCase();
    return 'AF-$year-$suffix';
  }
}
