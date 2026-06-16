// lib/models/restaurant_model.dart
// ? Compatible Firestore (vrais restaurants) + fallback local

class Plat {
  final String name;
  final String price;
  final String img;
  final String description;
  final String category;
  final bool isAvailable;
  final List<Map<String, dynamic>> supplements;

  const Plat({
    required this.name,
    required this.price,
    required this.img,
    this.description = '',
    this.category = 'Plat',
    this.isAvailable = true,
    this.supplements = const [],
  });

  int get priceInt {
    final cleaned = price.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  factory Plat.fromFirestore(Map<String, dynamic> json) => Plat(
        name: json['name'] as String? ?? '',
        price: () {
          final p = json['price'];
          if (p == null) return '0 FCFA';
          if (p is num) return '${p.toInt()} FCFA';
          return '$p';
        }(),
        img: json['img'] as String? ??
            json['imageUrl'] as String? ??
            json['image'] as String? ??
            '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Plat',
        isAvailable: json['isAvailable'] as bool? ?? true,
        supplements: (json['supplements'] as List?)
                ?.map((s) => Map<String, dynamic>.from(s as Map))
                .toList() ??
            [],
      );

  factory Plat.fromJson(Map<String, dynamic> json) => Plat.fromFirestore(json);
}

class Restaurant {
  final String id;
  final String name;
  final String style;
  final String coverImg;
  final String logoImg;
  final String description;
  final String address;
  final String phone;
  final String openingHours;
  final double rating;
  final int deliveryTime;
  final int minOrder;
  final List<String> tags;
  final List<Plat> plats;
  final String section;
  final bool isActive;
  final String ownerUid;
  final String momoNumber;
  final double lat;
  final double lng;
  final List<String> previewPhotos;
  final bool hasActivePromo;
  final Map<String, String> schedule;
  final int reviewCount;

  const Restaurant({
    required this.id,
    required this.name,
    required this.style,
    required this.coverImg,
    required this.logoImg,
    required this.description,
    required this.address,
    required this.phone,
    required this.openingHours,
    required this.rating,
    required this.deliveryTime,
    required this.minOrder,
    required this.tags,
    required this.plats,
    this.section = 'explore',
    this.isActive = true,
    this.ownerUid = '',
    this.momoNumber = '',
    this.lat = 6.3654,
    this.lng = 2.4183,
    this.previewPhotos = const [],
    this.hasActivePromo = false,
    this.schedule = const {},
    this.reviewCount = 0,
  });

  // Vérifier si le restaurant est ouvert maintenant
  // Format attendu : "06h00 - 22h00", "07h-00h", "10h00-23h00"
  bool get isCurrentlyOpen {
    try {
      final regex = RegExp(
          r'(\d{1,2})h(\d{0,2})\s*[-éé]\s*(\d{1,2})h(\d{0,2})');
      final match = regex.firstMatch(openingHours);
      if (match == null) return true;

      final openH = int.parse(match.group(1)!);
      final openM = int.tryParse(match.group(2) ?? '') ?? 0;
      final closeH = int.parse(match.group(3)!);
      final closeM = int.tryParse(match.group(4) ?? '') ?? 0;

      final now = DateTime.now();
      final cur = now.hour * 60 + now.minute;
      final open = openH * 60 + openM;
      // 00h = minuit = fin de journée (24:00)
      final close = closeH == 0 ? 24 * 60 : closeH * 60 + closeM;

      return cur >= open && cur < close;
    } catch (_) {
      return true;
    }
  }

  // DEPUIS FIRESTORE
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? '').toString();

    final coverImg = json['coverImage'] as String? ??
        json['coverImg'] as String? ??
        json['logoUrl'] as String? ??
        json['logoImage'] as String? ??
        json['logoImg'] as String? ??
        '';

    final logoImg = json['logoUrl'] as String? ??
        json['logoImage'] as String? ??
        json['logoImg'] as String? ??
        json['coverImage'] as String? ??
        json['coverImg'] as String? ??
        '';

    final platsList = json['plats'] as List? ?? [];
    final plats = platsList
        .map((p) =>
            Plat.fromFirestore(p is Map ? Map<String, dynamic>.from(p) : {}))
        .where((p) => p.name.isNotEmpty)
        .toList();

    final section = json['section'] as String? ?? 'explore';
    final rating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    final tags =
        (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    final categorie = json['categorie'] as String? ?? json['style'] as String? ?? '';
    final finalTags = tags.isNotEmpty ? tags : (categorie.isNotEmpty ? [categorie] : <String>[]);

    return Restaurant(
      id: id,
      name: json['name'] as String? ?? '',
      style: json['style'] as String? ?? '',
      coverImg: coverImg,
      logoImg: logoImg,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      openingHours: json['openingHours'] as String? ??
          json['hours'] as String? ??
          '08h-22h',
      rating: rating,
      deliveryTime: (json['deliveryTime'] as num?)?.toInt() ?? 30,
      minOrder: (json['minOrder'] as num?)?.toInt() ?? 1000,
      tags: finalTags,
      plats: plats,
      section: section,
      isActive: json['isActive'] as bool? ?? true,
      ownerUid: json['ownerUid'] as String? ?? '',
      momoNumber: json['momoNumber'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 6.3654,
      lng: (json['lng'] as num?)?.toDouble() ?? 2.4183,
      previewPhotos: (json['previewPhotos'] as List?)
              ?.map((e) => e.toString())
              .where((url) => url.isNotEmpty)
              .toList() ??
          [],
      hasActivePromo: json['hasActivePromo'] as bool? ?? false,
      schedule: () {
        final raw = json['schedule'];
        if (raw is Map) {
          return Map<String, String>.fromEntries(
            raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
          );
        }
        return <String, String>{};
      }(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ??
          (json['numRatings'] as num?)?.toInt() ??
          (json['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

