// lib/models/review_model.dart
// Sous-collection Firestore : restaurants/{id}/reviews

import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String clientUid;
  final String clientName;
  final String? clientImageUrl;
  final double rating;    // 1.0 é 5.0
  final String comment;
  final String? orderId;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.clientUid,
    required this.clientName,
    this.clientImageUrl,
    required this.rating,
    required this.comment,
    this.orderId,
    this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? createdAt;
    try {
      final ts = map['createdAt'];
      if (ts is Timestamp) createdAt = ts.toDate();
    } catch (_) {}

    return ReviewModel(
      id: id,
      clientUid: map['clientUid'] as String? ?? '',
      clientName: map['clientName'] as String? ?? 'Anonyme',
      clientImageUrl: map['clientImageUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String? ?? '',
      orderId: map['orderId'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'clientUid': clientUid,
        'clientName': clientName,
        'clientImageUrl': clientImageUrl,
        'rating': rating,
        'comment': comment,
        if (orderId != null) 'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// Service Firestore pour les avis
class ReviewService {
  static CollectionReference<Map<String, dynamic>> _col(String restaurantId) =>
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('reviews');

  static Future<List<ReviewModel>> getReviews(String restaurantId,
      {int limit = 20}) async {
    try {
      final snap = await _col(restaurantId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ReviewModel.fromMap(d.data(), d.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> hasAlreadyReviewed(
      String restaurantId, String clientUid) async {
    try {
      final snap = await _col(restaurantId)
          .where('clientUid', isEqualTo: clientUid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> addReview(String restaurantId, ReviewModel review) async {
    await _col(restaurantId).add(review.toMap());
    // Recalculer la note moyenne du restaurant
    await _updateAverageRating(restaurantId);
  }

  static Future<void> _updateAverageRating(String restaurantId) async {
    try {
      final snap = await _col(restaurantId).get();
      if (snap.docs.isEmpty) return;
      final avg = snap.docs
              .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b) /
          snap.docs.length;
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .update({'rating': double.parse(avg.toStringAsFixed(1))});
    } catch (_) {}
  }
}
