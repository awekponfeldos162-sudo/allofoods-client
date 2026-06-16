// lib/pages/restaurantpage.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'RestaurantProfilPage.dart';
import 'package:shimmer/shimmer.dart';
import '../models/restaurant_model.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});
  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  List<Restaurant> _all = [];
  List<Restaurant> _results = [];
  bool _loading = true;
  String _query = '';
  String _filterTag = 'Tous';
  String _sortBy = 'Note';

  List<String> _tags = ['Tous'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadCategories(), _loadRestaurants()]);
  }

  // Catégories dynamiques depuis Firestore
  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .where('active', isEqualTo: true)
          .orderBy('order')
          .get();
      final cats = snap.docs
          .map((d) => d.data()['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (mounted && cats.isNotEmpty) {
        setState(() => _tags = ['Tous', ...cats]);
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _tags = ['Tous', 'Fast Food', 'Africain', 'Pizza', 'Snack']);
      }
    }
  }

  Future<void> _loadRestaurants() async {
    if (mounted) setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
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
          .where((r) => r.name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _all = list;
        _results = _sorted(list);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _all = [];
        _results = [];
        _loading = false;
      });
    }
  }

  List<Restaurant> _sorted(List<Restaurant> list) {
    final copy = List<Restaurant>.from(list);
    switch (_sortBy) {
      case 'Note':
        copy.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Temps':
        copy.sort((a, b) => a.deliveryTime.compareTo(b.deliveryTime));
        break;
      default:
        break; // 'Distance' é pas de coordonnées, ordre original conservé
    }
    return copy;
  }

  void _filter() {
    setState(() {
      final filtered = _all.where((r) {
        final matchQuery = _query.isEmpty ||
            r.name.toLowerCase().contains(_query.toLowerCase()) ||
            r.style.toLowerCase().contains(_query.toLowerCase()) ||
            r.tags.any((t) => t.toLowerCase().contains(_query.toLowerCase()));
        final matchTag = _filterTag == 'Tous' ||
            r.style.toLowerCase().contains(_filterTag.toLowerCase()) ||
            r.tags
                .any((t) => t.toLowerCase().contains(_filterTag.toLowerCase()));
        return matchQuery && matchTag;
      }).toList();
      _results = _sorted(filtered);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final searchBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // Barre de recherche
        Container(
          color: searchBg,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(children: [
            TextField(
              onChanged: (v) {
                _query = v;
                _filter();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _query = '';
                          _filter();
                        })
                    : null,
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 8),
            // Filtres catégories (dynamiques depuis Firestore)
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tags.length,
                itemBuilder: (_, i) {
                  final active = _filterTag == _tags[i];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _filterTag = _tags[i]);
                      _filter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: active ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active
                                  ? Colors.orange
                                  : Colors.grey.shade300)),
                      child: Text(_tags[i],
                          style: TextStyle(
                              color: active ? Colors.white : Colors.grey,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),

        // Compteur + Tri
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(children: [
              Text(
                  '${_results.length} restaurant${_results.length > 1 ? "s" : ""}',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  icon:
                      const Icon(Icons.sort, color: Colors.orange, size: 16),
                  items: ['Note', 'Temps', 'Distance']
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _sortBy = v);
                      _filter();
                    }
                  },
                ),
              ),
            ]),
          ),

        // Grille
        Expanded(
          child: _loading
              ? _ShimmerGrid()
              : _results.isEmpty
                  ? _EmptyState(hasQuery: _query.isNotEmpty)
                  : RefreshIndicator(
                      color: Colors.orange,
                      onRefresh: _loadRestaurants,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (_, i) =>
                            _RestaurantCard(restaurant: _results[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// Squelette shimmer affiché pendant le chargement
class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 115,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 13, width: 100, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 70, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 120, color: Colors.white),
                    const SizedBox(height: 12),
                    Container(
                        height: 30,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20))),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final isFav = favs.isFavRestaurant(restaurant.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RestaurantProfilePage(restaurant: restaurant)));
          },
          child: Container(
            decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(children: [
                  _PhotoCarousel(
                    photos: restaurant.previewPhotos.isNotEmpty
                        ? restaurant.previewPhotos
                        : (restaurant.coverImg.isNotEmpty
                            ? [restaurant.coverImg]
                            : []),
                    height: 115,
                  ),
                  Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                          icon: Icons.delivery_dining,
                          label: '${restaurant.deliveryTime} min',
                          color: Colors.black54)),
                  Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          favs.toggleRestaurant(restaurant.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.white,
                            size: 14,
                          ),
                        ),
                      )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(restaurant.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                            child: Text(restaurant.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10))),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => RestaurantProfilePage(
                                        restaurant: restaurant)));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                          child: const Text('Voir le menu',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
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

// Carousel automatique des photos de plats du restaurant
class _PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final double height;
  const _PhotoCarousel({required this.photos, required this.height});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late final PageController _ctrl = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    if (widget.photos.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _current = (_current + 1) % widget.photos.length;
        _ctrl.animateToPage(
          _current,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _gradient() => Container(
        height: widget.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9800), Color(0xFFE65100)],
          ),
        ),
        child: const Center(
            child: Icon(Icons.restaurant, size: 40, color: Colors.white70)),
      );

  Widget _buildImage(String url) {
    if (!url.startsWith('http')) {
      return url.isNotEmpty
          ? Image.asset(url,
              width: double.infinity,
              height: widget.height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradient())
          : _gradient();
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: widget.height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(height: widget.height, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _gradient(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return _gradient();
    if (widget.photos.length == 1) return _buildImage(widget.photos[0]);

    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => _buildImage(widget.photos[i]),
        ),
        // Indicateurs de position (dots)
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: _current == i ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _current == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(hasQuery ? Icons.search_off : Icons.storefront_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(hasQuery ? 'Aucun résultat' : 'Aucun restaurant disponible',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}
