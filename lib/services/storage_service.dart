// lib/services/storage_service.dart
// Upload photos vers Supabase Storage (HTTP direct é contourne le SDK)
// Buckets : Profils | Logos | Aliments

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/config/env_config.dart';

class StorageService {
  // Buckets (noms exacts dans la console Supabase)
  static String get bucketProfiles => Env.supabaseBucketProfiles;
  static String get bucketLogos    => Env.supabaseBucketLogos;
  static String get bucketFoods    => Env.supabaseBucketFoods;

  static String get _baseUrl => '${Env.supabaseUrl}/storage/v1/object';
  static String get _anonKey => Env.supabaseAnonKey;

  // UPLOAD DEPUIS BYTES é HTTP direct, compatible partout
  static Future<String?> uploadBytes(
    Uint8List bytes, {
    required String bucket,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final url = Env.supabaseUrl;
      final key = Env.supabaseAnonKey;
      if (url.isEmpty || key.isEmpty) return null;

      final uri = Uri.parse('$url/storage/v1/object/$bucket/$path');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return '$url/storage/v1/object/public/$bucket/$path';
      }
      debugPrint('[Storage] upload error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[Storage] exception: $e');
      return null;
    }
  }

  // UPLOAD DEPUIS Uint8List é profils utilisateurs
  // Appelé avec: await xfile.readAsBytes()
  static Future<String?> uploadImage(
    Uint8List bytes, {
    String? bucket,
    String? fileName,
  }) async {
    final name = fileName ?? _timestamp('jpg');
    return uploadBytes(
      bytes,
      bucket: bucket ?? bucketProfiles,
      path: name,
    );
  }

  // UPLOAD DEPUIS BASE64 (sans header data:image/...)
  static Future<String?> uploadBase64(
    String base64Img, {
    String? bucket,
    String? fileName,
  }) async {
    try {
      // Enlève le header "data:image/jpeg;base64," si présent
      final clean = base64Img.contains(',') ? base64Img.split(',').last : base64Img;
      final bytes = Uint8List.fromList(base64Decode(clean));
      final name  = fileName ?? _timestamp('jpg');
      return uploadBytes(
        bytes,
        bucket: bucket ?? bucketProfiles,
        path: name,
      );
    } catch (e) {
      debugPrint('[Storage] uploadBase64 : $e');
      return null;
    }
  }

  // UPLOAD LOGO RESTAURANT
  static Future<String?> uploadLogo(Uint8List bytes, {String? restaurantId}) async {
    final name = restaurantId != null ? '$restaurantId.jpg' : _timestamp('jpg');
    return uploadBytes(bytes, bucket: bucketLogos, path: name);
  }

  // UPLOAD PHOTO PLAT
  static Future<String?> uploadFoodPhoto(Uint8List bytes, {String? itemId}) async {
    final name = itemId != null ? '$itemId.jpg' : _timestamp('jpg');
    return uploadBytes(bytes, bucket: bucketFoods, path: name);
  }

  // SUPPRIMER UN FICHIER
  static Future<void> deleteFile(String bucket, String path) async {
    try {
      final uri = Uri.parse('$_baseUrl/$bucket/$path');
      await http.delete(uri, headers: {'Authorization': 'Bearer $_anonKey'});
    } catch (e) {
      debugPrint('[Storage] deleteFile ($bucket/$path) : $e');
    }
  }

  static String _timestamp(String ext) =>
      '${DateTime.now().millisecondsSinceEpoch}.$ext';
}
