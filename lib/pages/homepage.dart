// lib/pages/homepage.dart
// Accueil allofoods é restaurants Firestore + localisation + recherche + avatar
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import 'RestaurantProfilPage.dart';
import 'adressePage.dart';
import 'restaurantpage.dart';
import '../widgets/ad_carousel.dart';
import '../models/cart_model.dart';
import 'promo_page.dart';
import '../l10n/app_localizations.dart';

// Couple plat + restaurant pour les sections horizontales
class _PlatItem {
  final Plat plat;
  final Restaurant restaurant;
  const _PlatItem(this.plat, this.restaurant);
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<Restaurant> _featured = [];
  List<Restaurant> _daily = [];
  List<Restaurant> _explore = [];
  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _promoRestaurants = [];
  List<_PlatItem> _breakfastPlats = [];
  List<_PlatItem> _popularPlats = [];
  List<_PlatItem> _lunchPlats = [];
  String _selectedCategory = 'Tous';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      List<Restaurant> all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return Restaurant.fromJson(data);
      }).toList();

      debugPrint('[Homepage] ${all.length} restaurants Firestore');
      _allRestaurants = all;
      _applyCategory();
    } catch (e) {
      debugPrint('[Homepage] Erreur Firestore: $e');
      _allRestaurants = [];
      _applyCategory();
    }
  }

  void _applyCategory() {
    final filtered = _selectedCategory == 'Tous'
        ? _allRestaurants
        : _allRestaurants.where((r) {
            final q = _selectedCategory.toLowerCase();
            return r.tags.any((t) => t.toLowerCase().contains(q)) ||
                r.style.toLowerCase().contains(q);
          }).toList();
    _apply(filtered);
  }

  void _apply(List<Restaurant> all) {
    if (!mounted) return;

    var featured = all.where((r) => r.section == 'featured').toList();
    var daily = all.where((r) => r.section == 'daily').toList();
    var explore = all.where((r) => r.section == 'explore').toList();

    if (featured.isEmpty && daily.isEmpty && explore.isEmpty) {
      featured = all.take(2).toList();
      daily = all.length > 2
          ? all.sublist(2, (all.length > 5 ? 5 : all.length))
          : [];
      explore = all.length > 5 ? all.sublist(5) : [];
    } else {
      if (featured.isEmpty) featured = all.take(2).toList();
      if (daily.isEmpty && all.length > 2)
        daily = all.sublist(2, (all.length > 5 ? 5 : all.length));
      if (explore.isEmpty && all.length > 5) explore = all.sublist(5);
    }

    final entries = all
        .where((r) => r.plats.isNotEmpty)
        .expand((r) =>
            r.plats.where((p) => p.isAvailable).map((p) => _PlatItem(p, r)))
        .toList();

    const breakfastCats = [
      'petit-déjeuner', 'breakfast', 'viennois', 'matin', 'brunch', 'petit déjeuner'
    ];
    const lunchCats = [
      'midi', 'déjeuner', 'plat', 'africain', 'traditionnel', 'lunch', 'principal', 'riz', 'poulet'
    ];

    final breakfast = entries
        .where((e) { final c = e.plat.category.toLowerCase(); return breakfastCats.any((k) => c.contains(k)); })
        .take(10)
        .toList();

    final popular = [...entries]
      ..sort((a, b) => b.restaurant.rating.compareTo(a.restaurant.rating));

    final lunch = entries
        .where((e) { final c = e.plat.category.toLowerCase(); return lunchCats.any((k) => c.contains(k)); })
        .take(10)
        .toList();

    setState(() {
      _featured = featured;
      _daily = daily;
      _explore = explore;
      _promoRestaurants = all.where((r) => r.hasActivePromo).toList();
      _breakfastPlats = breakfast;
      _popularPlats = popular.take(10).toList();
      _lunchPlats = lunch;
      _loading = false;
    });
  }

  void _open(Restaurant r) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RestaurantProfilePage(restaurant: r)),
    );
  }

  void _goToRestaurants() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RestaurantPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;

    if (_loading) {
      return Container(
          color: bg,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.orange)));
    }

    final proches = _allRestaurants.take(8).toList();
    final t = AppLocalizations.of(context);

    return Container(
      color: bg,
      child: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            _LocationBar(isDark: isDark),
            _SearchBar(isDark: isDark),
            _CategoryFilter(
              selected: _selectedCategory,
              isDark: isDark,
              onSelect: (cat) {
                if (_selectedCategory == cat) return;
                setState(() => _selectedCategory = cat);
                _applyCategory();
              },
            ),

            const AdCarousel(),

            if (_promoRestaurants.isNotEmpty) ...[
              _Header(t.offersAndPromos, onSeeAll: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PromoPage(restaurants: _promoRestaurants),
                    ));
              }),
              _PromoList(items: _promoRestaurants, onTap: _open),
            ],

            if (_breakfastPlats.isNotEmpty) ...[
              _Header(t.breakfast, onSeeAll: _goToRestaurants),
              _HPlatList(items: _breakfastPlats, onTap: (e) => _open(e.restaurant)),
            ],

            if (_allRestaurants.isNotEmpty) ...[
              _Header(t.sectionFeatured, onSeeAll: _goToRestaurants),
              _HRestaurantList(
                items: _featured.isNotEmpty
                    ? _featured
                    : _allRestaurants.take(8).toList(),
                onTap: _open,
              ),
            ],

            if (_popularPlats.isNotEmpty) ...[
              _Header(t.popularDishes, onSeeAll: _goToRestaurants),
              _HPlatList(items: _popularPlats, onTap: (e) => _open(e.restaurant)),
            ],

            if (_daily.isNotEmpty) ...[
              _Header(t.sectionDaily, onSeeAll: _goToRestaurants),
              _Carousel(items: _daily, onTap: _open),
            ],

            if (_lunchPlats.isNotEmpty) ...[
              _Header(t.lunchDishes, onSeeAll: _goToRestaurants),
              _HPlatList(items: _lunchPlats, onTap: (e) => _open(e.restaurant)),
            ],

            if (proches.isNotEmpty) ...[
              _Header(t.restaurantsNearby, onSeeAll: _goToRestaurants),
              _HRestaurantList(items: proches, onTap: _open),
            ],

            if (_explore.isNotEmpty) ...[
              _Header(t.otherRestaurants, onSeeAll: _goToRestaurants),
              _Grid(items: _explore, onTap: _open),
              _SeeMoreBtn(onTap: _goToRestaurants),
            ],

            if (_allRestaurants.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.restaurant, size: 60, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(t.noRestaurantsAvailable,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(t.comeBackSoon,
                        style: const TextStyle(color: Colors.grey)),
                  ]),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// BARRE DE LOCALISATION + AVATAR
class _LocationBar extends StatelessWidget {
  final bool isDark;
  const _LocationBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        // Zone de livraison é tap ? AdressePage
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdressePage())),
            child: Row(children: [
              const Icon(Icons.location_on, color: Colors.orange, size: 20),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context).deliveryTo,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400)),
                Row(children: [
                  Text('Cotonou',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: Colors.orange),
                ]),
              ]),
            ]),
          ),
        ),

        // Avatar utilisateur (photo ou initiales)
        if (uid != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (_, snap) {
              final data = snap.data?.data() as Map<String, dynamic>? ?? {};
              final photoUrl = (data['photoUrl'] as String?)?.isNotEmpty == true
                  ? data['photoUrl'] as String
                  : (data['photoURL'] as String?)?.isNotEmpty == true
                      ? data['photoURL'] as String
                      : '';
              final name = data['displayName'] as String? ??
                  data['name'] as String? ??
                  '';
              final initials = name.isNotEmpty
                  ? name.trim().split(' ').map((w) => w[0]).take(2).join()
                  : '?';

              return GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: photoUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(photoUrl),
                      )
                    : CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.orange,
                        child: Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
              );
            },
          ),
      ]),
    );
  }
}

// BARRE DE RECHERCHE (navigation)
class _SearchBar extends StatelessWidget {
  final bool isDark;
  const _SearchBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RestaurantPage()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Row(children: [
            Icon(Icons.search, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context).searchHint,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _Header(this.title, {this.onSeeAll});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Row(children: [
                  Text(AppLocalizations.of(context).seeAll,
                      style: TextStyle(
                          color: const Color.fromARGB(255, 242, 145, 48),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right,
                      color: Colors.orange.shade600, size: 18),
                ]),
              ),
          ],
        ),
      );
}

class _SeeMoreBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeMoreBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.restaurant_menu,
                  color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).seeMoreRestaurants,
                  style: TextStyle(
                      color: const Color.fromARGB(255, 5, 4, 3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.2)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.orange.shade700, size: 15),
            ]),
          ),
        ),
      );
}

// LISTE HORIZONTALE RESTAURANTS
class _HRestaurantList extends StatelessWidget {
  final List<Restaurant> items;
  final void Function(Restaurant) onTap;
  const _HRestaurantList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 212,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          itemCount: items.length,
          itemBuilder: (_, i) =>
              _HRestaurantCard(r: items[i], onTap: () => onTap(items[i])),
        ),
      );
}

// CARTE RESTAURANT HORIZONTALE
class _HRestaurantCard extends StatelessWidget {
  final Restaurant r;
  final VoidCallback onTap;
  const _HRestaurantCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final isFav = favs.isFavRestaurant(r.id);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(children: [
                  _Img(img: r.coverImg, width: 160, height: 100),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OpenBadge(isOpen: r.isCurrentlyOpen),
                          if (r.hasActivePromo) ...[
                            const SizedBox(height: 3),
                            const _PromoBadge(),
                          ],
                        ]),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        favs.toggleRestaurant(r.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle),
                        child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.white,
                            size: 14),
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(r.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.orange.shade600, fontSize: 11)),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        Text(' ${r.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 6),
                        const Icon(Icons.timer, size: 12, color: Colors.grey),
                        Text(' ${r.deliveryTime}m',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ]),
                    ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// LISTE HORIZONTALE PLATS
class _HPlatList extends StatelessWidget {
  final List<_PlatItem> items;
  final void Function(_PlatItem) onTap;
  const _HPlatList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 205,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          itemCount: items.length,
          itemBuilder: (_, i) =>
              _HPlatCard(item: items[i], onTap: () => onTap(items[i])),
        ),
      );
}

// CARTE PLAT HORIZONTALE
class _HPlatCard extends StatelessWidget {
  final _PlatItem item;
  final VoidCallback onTap;
  const _HPlatCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plat = item.plat;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _Img(img: plat.img, width: 150, height: 95),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(item.restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text('${plat.priceInt} F',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                Consumer<CartProvider>(
                  builder: (_, cart, __) {
                    final inCart = cart.items.any((i) =>
                        i.name == plat.name &&
                        i.restaurantId == item.restaurant.id);
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        cart.addItem(
                          name: plat.name,
                          price: '${plat.priceInt}',
                          img: plat.img,
                          restaurantName: item.restaurant.name,
                          restaurantId: item.restaurant.id,
                        );
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: inCart
                                ? const Color.fromARGB(255, 242, 170, 4)
                                : Colors.orange,
                            shape: BoxShape.circle),
                        child: Icon(inCart ? Icons.check : Icons.add,
                            color: Colors.white, size: 14),
                      ),
                    );
                  },
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// CAROUSEL
class _Carousel extends StatefulWidget {
  final List<Restaurant> items;
  final void Function(Restaurant) onTap;
  const _Carousel({required this.items, required this.onTap});
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.85);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_page + 1) % widget.items.length;
        _ctrl.animateToPage(next,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 200,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final r = widget.items[i];
            return Consumer<FavoritesProvider>(
              builder: (_, favs, __) {
                final isFav = favs.isFavRestaurant(r.id);
                return GestureDetector(
                  onTap: () => widget.onTap(r),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(children: [
                        _Img(
                            img: r.coverImg,
                            width: double.infinity,
                            height: 200),
                        Container(
                            decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent
                            ],
                          ),
                        )),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              favs.toggleRestaurant(r.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle),
                              child: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav ? Colors.red : Colors.white,
                                  size: 18),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OpenBadge(isOpen: r.isCurrentlyOpen),
                              if (r.hasActivePromo) ...[
                                const SizedBox(height: 4),
                                const _PromoBadge(),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17)),
                                Text(r.style,
                                    style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.star,
                                      size: 12, color: Colors.amber),
                                  Text(' ${r.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.timer,
                                      size: 12, color: Colors.white70),
                                  Text(' ${r.deliveryTime} min',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                ]),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            widget.items.length,
            (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i ? Colors.orange : Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
      ),
    ]);
  }
}

// GRID
class _Grid extends StatelessWidget {
  final List<Restaurant> items;
  final void Function(Restaurant) onTap;
  const _Grid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.80,
        ),
        itemBuilder: (_, i) {
          final r = items[i];
          return Consumer<FavoritesProvider>(
            builder: (_, favs, __) {
              final isFav = favs.isFavRestaurant(r.id);
              return GestureDetector(
                onTap: () => onTap(r),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                          child: Stack(children: [
                            _Img(
                                img: r.coverImg,
                                width: double.infinity,
                                height: 105),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _OpenBadge(isOpen: r.isCurrentlyOpen),
                                  if (r.hasActivePromo) ...[
                                    const SizedBox(height: 3),
                                    const _PromoBadge(),
                                  ],
                                ],
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  favs.toggleRestaurant(r.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.35),
                                      shape: BoxShape.circle),
                                  child: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav ? Colors.red : Colors.white,
                                      size: 14),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(r.style,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.orange.shade600,
                                        fontSize: 11)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.star,
                                      size: 12, color: Colors.amber),
                                  Text(' ${r.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(fontSize: 11)),
                                  const Spacer(),
                                  const Icon(Icons.timer,
                                      size: 12, color: Colors.grey),
                                  Text(' ${r.deliveryTime}m',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ]),
                              ]),
                        ),
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// BADGE PROMO
class _PromoBadge extends StatelessWidget {
  const _PromoBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer, size: 9, color: Colors.white),
          SizedBox(width: 3),
          Text('Promo',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ]),
      );
}

// BADGE OUVERT / FERMé
class _OpenBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isOpen ? 'Ouvert' : 'Fermé',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      );
}

// FILTRES CATÉGORIES
class _CategoryFilter extends StatelessWidget {
  final String selected;
  final bool isDark;
  final void Function(String) onSelect;
  const _CategoryFilter({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  static const _labels = [
    'Tous',
    'Burger',
    'Pizza',
    'Poulet',
    'Africain',
    'Grillades',
    'Sandwich',
    'Boulangerie',
  ];
  static const _icons = [
    Icons.apps_rounded,
    Icons.lunch_dining,
    Icons.local_pizza,
    Icons.set_meal,
    Icons.restaurant,
    Icons.outdoor_grill,
    Icons.fastfood,
    Icons.bakery_dining,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        itemCount: _labels.length,
        itemBuilder: (_, i) {
          final label = _labels[i];
          final icon = _icons[i];
          final isSelected = selected == label;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange
                    : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// SECTION PROMOTIONS
class _PromoList extends StatelessWidget {
  final List<Restaurant> items;
  final void Function(Restaurant) onTap;
  const _PromoList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 148,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          itemCount: items.length,
          itemBuilder: (_, i) =>
              _PromoCard(r: items[i], onTap: () => onTap(items[i])),
        ),
      );
}

class _PromoCard extends StatelessWidget {
  final Restaurant r;
  final VoidCallback onTap;
  const _PromoCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            // Image de fond
            _Img(img: r.coverImg, width: 290, height: 148),

            // Gradient sombre
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),

            // Contenu
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge PROMO
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(8),
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

                  // Infos restaurant
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(r.style,
                            style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        Text(' ${r.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.timer,
                            size: 12, color: Colors.white70),
                        Text(' ${r.deliveryTime}m',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// IMAGE   gére URL réseau + assets local
class _Img extends StatelessWidget {
  final String img;
  final double? width;
  final double height;
  const _Img({required this.img, this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: width,
        height: height,
        color: Colors.orange.shade100,
        child: const Center(
            child: Icon(Icons.restaurant, color: Colors.orange, size: 30)));

    if (img.isEmpty) return fallback;

    if (img.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: img,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: width,
          height: height,
          color: Colors.orange.shade50,
          child: const Center(
              child:
                  CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => fallback,
      );
    }

    if (img.startsWith('assets/')) {
      return Image.asset(img,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }

    return fallback;
  }
}
