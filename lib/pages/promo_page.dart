// lib/pages/promo_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import 'RestaurantProfilPage.dart';

class PromoPage extends StatefulWidget {
  /// Si fournis depuis la HomePage, on évite un rechargement Firestore.
  final List<Restaurant>? restaurants;
  const PromoPage({super.key, this.restaurants});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  List<Restaurant> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.restaurants != null) {
      _items = widget.restaurants!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .where('hasActivePromo', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) {
            try {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return Restaurant.fromJson(data);
            } catch (_) {
              return null;
            }
          })
          .whereType<Restaurant>()
          .toList();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Plein de promos 🎉',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _items.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _PromoRestaurantCard(r: _items[i]),
                  ),
                ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Aucune promotion disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Revenez bientôt !',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );
}

// ── Carte restaurant promo ─────────────────────────────────────────────────
class _PromoRestaurantCard extends StatelessWidget {
  final Restaurant r;
  const _PromoRestaurantCard({required this.r});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final isFav = favs.isFavRestaurant(r.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RestaurantProfilePage(restaurant: r)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Image + badges ──────────────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(children: [
                  _AnyImage(img: r.coverImg, height: 180),

                  // Gradient bas pour lisibilité
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge OFFRE SPÉCIALE (haut gauche)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.local_fire_department,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text('OFFRE SPÉCIALE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ]),
                    ),
                  ),

                  // Bouton favori (haut droite)
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        favs.toggleRestaurant(r.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Temps de livraison (bas droite)
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: Colors.black54),
                        const SizedBox(width: 3),
                        Text('${r.deliveryTime} - ${r.deliveryTime + 10} mins',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ]),
                    ),
                  ),
                ]),
              ),

              // ── Infos restaurant ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Nom
                  Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),

                  // Note + livraison
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(r.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    const Icon(Icons.shopping_bag_outlined,
                        size: 15, color: Colors.blue),
                    const SizedBox(width: 3),
                    Text('Min ${r.minOrder} F',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ]),
                  const SizedBox(height: 8),

                  // Tags
                  if (r.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: r.tags
                          .take(5)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54)),
                              ))
                          .toList(),
                    ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// Image helper
class _AnyImage extends StatelessWidget {
  final String img;
  final double height;
  const _AnyImage({required this.img, required this.height});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: double.infinity,
        height: height,
        color: Colors.orange.shade100,
        child: const Center(
            child: Icon(Icons.restaurant, color: Colors.orange, size: 40)));

    if (img.isEmpty) return fallback;
    if (img.startsWith('http')) {
      return Image.network(img,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    if (img.startsWith('assets/')) {
      return Image.asset(img,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}
