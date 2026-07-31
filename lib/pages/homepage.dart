// lib/pages/homepage.dart
// Accueil allofoods — restaurants Firestore + localisation + recherche + avatar
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/premium.dart';
import 'RestaurantProfilPage.dart';
import 'adressePage.dart';
import 'restaurantpage.dart';
import '../widgets/ad_carousel.dart';
import '../models/cart_model.dart';
import '../models/delivery_model.dart' show DeliveryProvider;
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

  // ── Logique de données — inchangée ──────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Tous les restaurants approuvés — ouverts ou fermés (les fermés
      // restent visibles/explorables, juste non commandables, voir
      // RestaurantProfilPage / PanierPage).
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('is_approved', isEqualTo: true)
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
      if (daily.isEmpty && all.length > 2) {
        daily = all.sublist(2, (all.length > 5 ? 5 : all.length));
      }
      if (explore.isEmpty && all.length > 5) explore = all.sublist(5);
    }

    final entries = all
        .where((r) => r.plats.isNotEmpty)
        .expand((r) =>
            r.plats.where((p) => p.isAvailable).map((p) => _PlatItem(p, r)))
        .toList();

    const breakfastCats = [
      'petit-déjeuner',
      'breakfast',
      'viennois',
      'matin',
      'brunch',
      'petit déjeuner'
    ];
    const lunchCats = [
      'midi',
      'déjeuner',
      'plat',
      'africain',
      'traditionnel',
      'lunch',
      'principal',
      'riz',
      'poulet'
    ];

    final breakfast = entries
        .where((e) {
          final c = e.plat.category.toLowerCase();
          return breakfastCats.any((k) => c.contains(k));
        })
        .take(10)
        .toList();

    final popular = [...entries]
      ..sort((a, b) => b.restaurant.rating.compareTo(a.restaurant.rating));

    final lunch = entries
        .where((e) {
          final c = e.plat.category.toLowerCase();
          return lunchCats.any((k) => c.contains(k));
        })
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

  void _goToRestaurants([String? sectionTitle]) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RestaurantPage(sectionTitle: sectionTitle)),
    );
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.dark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    if (_loading) {
      return Container(color: bg, child: const _HomeSkeleton());
    }

    final proches = _allRestaurants.take(8).toList();
    final t = AppLocalizations.of(context);

    return Container(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              const _LocationBar(),
              const AdCarousel(),
              const _SearchBar(),
              _CategoryFilter(
                selected: _selectedCategory,
                onSelect: (cat) {
                  if (_selectedCategory == cat) return;
                  setState(() => _selectedCategory = cat);
                  _applyCategory();
                },
              ),
              if (_promoRestaurants.isNotEmpty) ...[
                _Header(t.offersAndPromos, onSeeAll: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PromoPage(restaurants: _promoRestaurants),
                      ));
                }),
                _PromoList(items: _promoRestaurants, onTap: _open),
              ],
              if (_breakfastPlats.isNotEmpty) ...[
                _Header(t.breakfast,
                    onSeeAll: () => _goToRestaurants(t.breakfast)),
                _HPlatList(
                    items: _breakfastPlats, onTap: (e) => _open(e.restaurant)),
              ],
              if (_allRestaurants.isNotEmpty) ...[
                _Header(t.sectionFeatured,
                    onSeeAll: () => _goToRestaurants(t.sectionFeatured)),
                _HRestaurantList(
                  items: _featured.isNotEmpty
                      ? _featured
                      : _allRestaurants.take(8).toList(),
                  onTap: _open,
                ),
              ],
              if (_popularPlats.isNotEmpty) ...[
                _Header(t.popularDishes,
                    onSeeAll: () => _goToRestaurants(t.popularDishes)),
                _HPlatList(
                    items: _popularPlats, onTap: (e) => _open(e.restaurant)),
              ],
              if (_daily.isNotEmpty) ...[
                _Header(t.sectionDaily,
                    onSeeAll: () => _goToRestaurants(t.sectionDaily)),
                _Carousel(items: _daily, onTap: _open),
              ],
              if (_lunchPlats.isNotEmpty) ...[
                _Header(t.lunchDishes,
                    onSeeAll: () => _goToRestaurants(t.lunchDishes)),
                _HPlatList(
                    items: _lunchPlats, onTap: (e) => _open(e.restaurant)),
              ],
              if (proches.isNotEmpty) ...[
                _Header(t.restaurantsNearby,
                    onSeeAll: () => _goToRestaurants(t.restaurantsNearby)),
                _HRestaurantList(items: proches, onTap: _open),
              ],
              if (_explore.isNotEmpty) ...[
                _Header(t.otherRestaurants,
                    onSeeAll: () => _goToRestaurants(t.otherRestaurants)),
                _Grid(items: _explore, onTap: _open),
                _SeeMoreBtn(onTap: () => _goToRestaurants(t.otherRestaurants)),
              ],
              if (_allRestaurants.isEmpty) _EmptyRestaurants(t: t),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ÉTAT VIDE PREMIUM ─────────────────────────────────────────────
class _EmptyRestaurants extends StatelessWidget {
  final AppLocalizations t;
  const _EmptyRestaurants({required this.t});

  @override
  Widget build(BuildContext context) {
    final texts = AppTextStyles.textTheme(Theme.of(context).brightness);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded,
                size: 52, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(t.noRestaurantsAvailable,
              style: texts.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(t.comeBackSoon,
              style: texts.bodyMedium, textAlign: TextAlign.center),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

// ── SKELETON DE CHARGEMENT INITIAL ────────────────────────────────
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SkeletonLoader.text(width: 160, height: 42),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 212,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 3,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child:
                  SizedBox(width: 170, child: SkeletonLoader.card(height: 212)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SkeletonLoader.list(count: 3, itemHeight: 76),
        ),
      ],
    );
  }
}

// BARRE DE LOCALISATION + SALUTATION + NOTIFICATIONS + AVATAR
class _LocationBar extends StatelessWidget {
  const _LocationBar();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final texts = AppTextStyles.textTheme(brightness);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final delivery = context.watch<DeliveryProvider>();
    // Premier segment de l'adresse (ex: "Akpakpa" plutôt que l'adresse
    // complète) — reste lisible dans la largeur limitée de la barre.
    final addressLabel = delivery.hasAddress
        ? delivery.clientAddress.split(',').first.trim()
        : 'Choisir une adresse';

    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, 10),
      child: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots()
            : null,
        builder: (_, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final photoUrl = (data['photoUrl'] as String?)?.isNotEmpty == true
              ? data['photoUrl'] as String
              : (data['photoURL'] as String?)?.isNotEmpty == true
                  ? data['photoURL'] as String
                  : '';
          final name =
              data['displayName'] as String? ?? data['name'] as String? ?? '';
          final firstName =
              name.trim().isNotEmpty ? name.trim().split(' ').first : '';
          final initials = name.isNotEmpty
              ? name.trim().split(' ').map((w) => w[0]).take(2).join()
              : '?';

          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Salutation + adresse (tap → AdressePage)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdressePage()));
                },
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonjour 👋', style: texts.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        firstName.isNotEmpty
                            ? name
                            : AppLocalizations.of(context).welcome,
                        style: texts.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.accent, size: 14),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(addressLabel,
                              style: texts.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: AppColors.accent),
                      ]),
                    ]),
              ),
            ),

            const SizedBox(width: 10),

            // Cloche de notifications
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(context, '/notifications');
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    size: 22),
              ),
            ),

            const SizedBox(width: 10),

            // Avatar utilisateur (photo ou initiales)
            if (uid != null)
              GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: photoUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 21, backgroundImage: NetworkImage(photoUrl))
                    : CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.secondary,
                        child: Text(initials.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
              ),
          ]);
        },
      ),
    );
  }
}

// BARRE DE RECHERCHE (navigation)
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    final isDark = brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 12),
      child: TapScale(
        pressedScale: 0.985,
        haptic: HapticFeedbackType.selection,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RestaurantPage())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color:
                isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            borderRadius: AppRadius.chipRadius,
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context).searchHint,
                style: texts.bodyMedium
                    ?.copyWith(color: texts.labelMedium?.color)),
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
  Widget build(BuildContext context) {
    final texts = AppTextStyles.textTheme(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: texts.headlineSmall)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSeeAll!();
              },
              child: Row(children: [
                Text(AppLocalizations.of(context).seeAll,
                    style: texts.labelMedium?.copyWith(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.accent, size: 18),
              ]),
            ),
        ],
      ),
    );
  }
}

class _SeeMoreBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeMoreBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 4),
      child: PremiumButton(
        label: AppLocalizations.of(context).seeMoreRestaurants,
        icon: Icons.restaurant_menu_rounded,
        outlined: true,
        height: 48,
        onPressed: onTap,
      ),
    );
  }
}

// LISTE HORIZONTALE RESTAURANTS — utilise le widget premium réutilisable
class _HRestaurantList extends StatelessWidget {
  final List<Restaurant> items;
  final void Function(Restaurant) onTap;
  const _HRestaurantList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 212,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 4),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final r = items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 178,
                child: Consumer<FavoritesProvider>(
                  builder: (_, favs, __) => AnimatedRestaurantCard(
                    restaurant: r,
                    imageHeight: 110,
                    onTap: () => onTap(r),
                    isFavorite: favs.isFavRestaurant(r.id),
                    onToggleFavorite: () => favs.toggleRestaurant(r.id),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (i * 60).ms)
                .slideX(begin: 0.08, end: 0);
          },
        ),
      );
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
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 4),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _HPlatCard(item: items[i], onTap: () => onTap(items[i])),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: (i * 60).ms)
              .slideX(begin: 0.08, end: 0),
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
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    final plat = item.plat;

    return SizedBox(
      width: 150,
      child: PremiumCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card)),
            child: _Img(img: plat.img, width: 150, height: 95),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.titleSmall),
              const SizedBox(height: 2),
              Text(item.restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodySmall),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text('${plat.priceInt} F',
                      style: AppTextStyles.priceAccent(size: 13)),
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
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: inCart ? AppColors.success : AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                                inCart
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                color: Colors.white,
                                size: 15)
                            .animate(target: inCart ? 1 : 0)
                            .scaleXY(end: 1.15, duration: 150.ms)
                            .then()
                            .scaleXY(end: 1, duration: 100.ms),
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

// CAROUSEL BANNIÈRE
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
    final brightness = Theme.of(context).brightness;
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
                return TapScale(
                  onTap: () => widget.onTap(r),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardRadius,
                      boxShadow: AppShadows.medium(brightness),
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.cardRadius,
                      child: Stack(children: [
                        _Img(
                            img: r.coverImg,
                            width: double.infinity,
                            height: 200),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.imageOverlay.withValues(alpha: 0.75),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
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
                                  color: AppColors.imageOverlay
                                      .withValues(alpha: 0.35),
                                  shape: BoxShape.circle),
                              child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav ? AppColors.error : Colors.white,
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
                                _OpenBadge(isOpen: r.isActive),
                                if (r.hasActivePromo) ...[
                                  const SizedBox(height: 4),
                                  const _PromoBadge()
                                ],
                              ]),
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
                                        color: Color(0xFFFFCC99),
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.star_rounded,
                                      size: 12, color: Color(0xFFFFB020)),
                                  Text(' ${r.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.timer_rounded,
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
              color: _page == i
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
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
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
              return (PremiumCard(
                onTap: () => onTap(r),
                padding: EdgeInsets.zero,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.card)),
                          child: Stack(fit: StackFit.expand, children: [
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
                                    _OpenBadge(isOpen: r.isActive),
                                    if (r.hasActivePromo) ...[
                                      const SizedBox(height: 3),
                                      const _PromoBadge()
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
                                      color: AppColors.imageOverlay
                                          .withValues(alpha: 0.35),
                                      shape: BoxShape.circle),
                                  child: Icon(
                                      isFav
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isFav
                                          ? AppColors.error
                                          : Colors.white,
                                      size: 14),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: texts.titleSmall),
                              const SizedBox(height: 2),
                              Text(r.style,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: texts.bodySmall),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Color(0xFFFFB020)),
                                Text(' ${r.rating.toStringAsFixed(1)}',
                                    style: texts.labelSmall),
                                const Spacer(),
                                Icon(Icons.timer_rounded,
                                    size: 12, color: texts.bodySmall?.color),
                                Text(' ${r.deliveryTime}m',
                                    style: texts.bodySmall),
                              ]),
                            ]),
                      ),
                    ]),
              ))
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                  .slideY(begin: 0.06, end: 0);
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
            color: AppColors.error, borderRadius: BorderRadius.circular(6)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer_rounded, size: 9, color: Colors.white),
          SizedBox(width: 3),
          Text('Promo',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ]),
      );
}

// BADGE OUVERT / FERMÉ
class _OpenBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: (isOpen ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isOpen ? 'Ouvert' : 'Fermé',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isOpen ? AppColors.success : AppColors.error,
          ),
        ),
      );
}

// FILTRES CATÉGORIES — icônes circulaires + libellé (façon "stories")
class _CategoryFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _CategoryFilter({required this.selected, required this.onSelect});

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
    Icons.lunch_dining_rounded,
    Icons.local_pizza_rounded,
    Icons.set_meal_rounded,
    Icons.restaurant_rounded,
    Icons.outdoor_grill_rounded,
    Icons.fastfood_rounded,
    Icons.bakery_dining_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final texts = AppTextStyles.textTheme(brightness);

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.sm, 8, AppSpacing.sm, 8),
        itemCount: _labels.length,
        itemBuilder: (_, i) {
          final label = _labels[i];
          final icon = _icons[i];
          final isSelected = selected == label;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TapScale(
              haptic: HapticFeedbackType.selection,
              onTap: () => onSelect(label),
              child: SizedBox(
                width: 64,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.categoryIconBg,
                      shape: BoxShape.circle,
                      boxShadow:
                          isSelected ? AppShadows.strong(brightness) : null,
                    ),
                    child: Icon(icon,
                        size: 24,
                        color:
                            isSelected ? Colors.white : AppColors.accentDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: texts.labelSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.accent
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ]),
              ),
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
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 4),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _PromoCard(r: items[i], onTap: () => onTap(items[i])),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: (i * 60).ms)
              .slideX(begin: 0.08, end: 0),
        ),
      );
}

class _PromoCard extends StatelessWidget {
  final Restaurant r;
  final VoidCallback onTap;
  const _PromoCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 290,
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardRadius,
          boxShadow: AppShadows.strong(brightness),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: Stack(fit: StackFit.expand, children: [
            _Img(img: r.coverImg, width: 290, height: 148),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.imageOverlay.withValues(alpha: 0.72),
                    AppColors.imageOverlay.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department_rounded,
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
                                color: Color(0xFFFFCC99),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFFFB020)),
                        Text(' ${r.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.timer_rounded,
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

// IMAGE — gère URL réseau + assets local, skeleton pendant chargement (règle #1)
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
        color: AppColors.accent.withValues(alpha: 0.08),
        child: const Center(
            child: Icon(Icons.restaurant_rounded,
                color: AppColors.accent, size: 30)));

    if (img.isEmpty) return fallback;

    if (img.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: img,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => SkeletonLoader.image(
            width: width, height: height, radius: BorderRadius.zero),
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
