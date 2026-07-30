// lib/pages/RestaurantProfilPage.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import '../models/cart_model.dart';
import '../models/review_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/premium.dart';
import 'PanierPage.dart';
import '../widgets/image_viewer.dart';
import 'plat_detail_page.dart';
import 'restaurant_detail_page.dart';

class RestaurantProfilePage extends StatefulWidget {
  final Restaurant restaurant;
  const RestaurantProfilePage({super.key, required this.restaurant});

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _categories = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Restaurant? _fullRestaurant;
  bool _loading = true;
  bool _collapsed = false;
  bool _sharing = false;

  static const double _coverHeight = 240;

  @override
  void initState() {
    super.initState();
    _loadFullRestaurant();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final isCollapsed = _scrollCtrl.hasClients &&
        _scrollCtrl.offset > _coverHeight - kToolbarHeight;
    if (isCollapsed != _collapsed) setState(() => _collapsed = isCollapsed);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final msg = '🍽️ Je vous recommande *${r.name}* sur AlloFoods !\n\n'
        '${r.style} • ${r.address}\n'
        '⭐ ${r.rating.toStringAsFixed(1)}  •  🕐 ${r.deliveryTime} min\n\n'
        'Commandez et faites-vous livrer rapidement 🚀';
    try {
      if (r.coverImg.startsWith('http')) {
        final res = await http.get(Uri.parse(r.coverImg));
        if (res.statusCode == 200) {
          final tmp =
              File('${Directory.systemTemp.path}/allofoods_${r.id}.jpg');
          await tmp.writeAsBytes(res.bodyBytes);
          await Share.shareXFiles([XFile(tmp.path)],
              text: msg, subject: r.name);
          return;
        }
      }
      await Share.share(msg, subject: r.name);
    } catch (_) {
      await Share.share(msg, subject: r.name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _loadFullRestaurant() async {
    Restaurant target = widget.restaurant;
    if (target.plats.isEmpty && target.id.isNotEmpty) {
      try {
        final data = await ApiService.getRestaurantById(target.id);
        if (data.isNotEmpty) target = Restaurant.fromJson(data);
      } catch (_) {}
    }
    if (!mounted) return;
    final cats = target.plats.map((p) => p.category).toSet().toList();
    final allCats = [...(cats.isEmpty ? ['Menu'] : cats), 'Avis'];
    setState(() {
      _fullRestaurant = target;
      _categories = allCats;
      _loading = false;
      _tabController = TabController(length: allCats.length, vsync: this);
    });
  }

  Restaurant get r => _fullRestaurant ?? widget.restaurant;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (_loading || _tabController == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(),
        body: const _RestaurantSkeleton(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      if (cart.items.isNotEmpty &&
          cart.restaurantId.isNotEmpty &&
          cart.restaurantId != r.id) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ Votre panier contient des articles de ${cart.restaurantName}. '
              'Ajouter ici videra votre panier.'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ));
      }
    });

    // Un restaurant fermé (hors horaires ou fermé manuellement) reste
    // explorable — seule la commande est bloquée (voir _PlatCard._addToCart).
    // isActive est la source de vérité temps réel (auto-fermé par la Cloud
    // Function enforceRestaurantHours dès l'heure de fermeture dépassée).
    final isOpen = r.isActive;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (ctx, _) => [
          // AppBar responsive : transparent sur image, thème quand scrollé
          SliverAppBar(
            pinned: true,
            expandedHeight: _coverHeight,
            backgroundColor: _collapsed ? Theme.of(ctx).scaffoldBackgroundColor : Colors.transparent,
            foregroundColor: _collapsed
                ? (brightness == Brightness.dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                : Colors.white,
            elevation: _collapsed ? 1 : 0,
            shadowColor: Colors.black26,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: _collapsed
                ? Text(r.name, style: AppTextStyles.textTheme(brightness).titleLarge, overflow: TextOverflow.ellipsis)
                : null,
            leading: _collapsed
                ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(ctx))
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: _CircleBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(ctx)),
                  ),
            actions: _collapsed
                ? [
                    IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => _scrollCtrl.animateTo(_coverHeight,
                          duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                    Consumer<FavoritesProvider>(
                      builder: (_, favs, __) {
                        final isFav = favs.isFavRestaurant(r.id);
                        return IconButton(
                          icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? AppColors.error : null),
                          onPressed: () => favs.toggleRestaurant(r.id),
                        );
                      },
                    ),
                    Consumer<CartProvider>(
                      builder: (ctx2, cart, _) => cart.itemCount > 0
                          ? IconButton(
                              icon: Badge(
                                label: Text('${cart.itemCount}'),
                                backgroundColor: AppColors.accent,
                                child: const Icon(Icons.shopping_cart_outlined),
                              ),
                              onPressed: () =>
                                  Navigator.push(ctx2, MaterialPageRoute(builder: (_) => const PanierPage())),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ]
                : [
                    Consumer<FavoritesProvider>(
                      builder: (_, favs, __) {
                        final isFav = favs.isFavRestaurant(r.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _CircleBtn(
                            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            onTap: () => favs.toggleRestaurant(r.id),
                            color: isFav ? AppColors.error : Colors.white,
                          ),
                        );
                      },
                    ),
                    Consumer<CartProvider>(
                      builder: (ctx2, cart, _) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CircleBtn(
                          icon: Icons.shopping_cart_outlined,
                          badge: cart.itemCount > 0 ? '${cart.itemCount}' : null,
                          onTap: () =>
                              Navigator.push(ctx2, MaterialPageRoute(builder: (_) => const PanierPage())),
                        ),
                      ),
                    ),
                  ],
            flexibleSpace: FlexibleSpaceBar(background: _buildCoverOnly(ctx, isOpen)),
          ),

          SliverToBoxAdapter(child: _buildRestaurantInfo(ctx, isOpen)),

          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBarDelegate(
              tabBar: TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondaryLight,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: _categories.map((c) => Tab(text: c)).toList(),
              ),
              bgColor: Theme.of(ctx).scaffoldBackgroundColor,
              searchCtrl: _searchCtrl,
              onSearch: (v) => setState(() => _searchQuery = v),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              searchQuery: _searchQuery,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController!,
          children: _categories.map((cat) {
            if (cat == 'Avis') {
              return _ReviewsTab(restaurantId: r.id, restaurantName: r.name);
            }
            final plats = r.plats.where((p) => p.category == cat && _matchSearch(p)).toList();
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, left: AppSpacing.md, right: AppSpacing.md, bottom: 100),
              itemCount: plats.isEmpty ? 1 : plats.length,
              itemBuilder: (context, i) {
                if (plats.isEmpty) {
                  return _EmptySearch(query: _searchQuery);
                }
                return _PlatCard(plat: plats[i], restaurant: r, isRestaurantOpen: isOpen)
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (i * 40).ms)
                    .slideY(begin: 0.04, end: 0);
              },
            );
          }).toList(),
        ),
      ),
      floatingActionButton: const _CartFAB(),
    );
  }

  // Image couverture seule (utilisée dans FlexibleSpaceBar)
  Widget _buildCoverOnly(BuildContext context, bool isOpen) {
    return Stack(fit: StackFit.expand, children: [
      Hero(
        tag: AnimatedRestaurantCard.heroTag(r.id),
        child: _AnyImage(img: r.coverImg, fit: BoxFit.cover),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.imageOverlay.withValues(alpha: 0.15), AppColors.imageOverlay.withValues(alpha: 0.65)],
          ),
        ),
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 56,
        left: AppSpacing.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isOpen ? AppColors.success : AppColors.error).withValues(alpha: 0.9),
            borderRadius: AppRadius.chipRadius,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isOpen ? Icons.circle : Icons.do_not_disturb_on_outlined, size: 8, color: Colors.white),
            const SizedBox(width: 4),
            Text(isOpen ? 'Ouvert' : 'Fermé',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
      Positioned(
        bottom: AppSpacing.md,
        left: AppSpacing.md,
        right: 80,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
          const SizedBox(height: 3),
          Text(r.style, style: const TextStyle(color: Color(0xFFFFCC99), fontSize: 13)),
        ]),
      ),
      Positioned(
        bottom: 12,
        right: AppSpacing.md,
        child: GestureDetector(
          onTap: () => ImageViewer.open(context, r.logoImg, 'logo_${r.id}'),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppShadows.medium(Brightness.light),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: ClipOval(child: _AnyImage(img: r.logoImg, width: 56, height: 56, fit: BoxFit.cover)),
            ),
          ),
        ),
      ),
    ]);
  }

  // Infos restaurant (tags, stats, adresse, description…)
  Widget _buildRestaurantInfo(BuildContext context, bool isOpen) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: r.tags
              .map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: AppRadius.chipRadius,
                    ),
                    child: Text(tag,
                        style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _StatChip(icon: Icons.star_rounded, color: const Color(0xFFFFB020), label: r.rating.toStringAsFixed(1)),
          const SizedBox(width: 14),
          _StatChip(icon: Icons.delivery_dining_rounded, color: AppColors.info, label: '${r.deliveryTime} min'),
          const SizedBox(width: 14),
          _StatChip(icon: Icons.shopping_bag_outlined, color: AppColors.success, label: 'Min ${r.minOrder} FCFA'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 14, color: texts.bodySmall?.color),
          const SizedBox(width: 3),
          Expanded(child: Text(r.address, style: texts.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(Icons.access_time_rounded, size: 14, color: texts.bodySmall?.color),
          const SizedBox(width: 3),
          Text(r.openingHours,
              style: TextStyle(
                  fontSize: 11, color: isOpen ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: texts.bodyMedium),
        const SizedBox(height: 8),
        if (!isOpen)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Ce restaurant est actuellement fermé. '
                    'Commandes autorisées uniquement durant les heures ouvrables.',
                    style: const TextStyle(fontSize: 11, color: AppColors.error)),
              ),
            ]),
          )
        else
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.phone_outlined, size: 14),
            label: Text(r.phone, style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailPage(restaurant: r)));
          },
          child: Row(children: [
            Icon(Icons.info_outline, size: 15, color: texts.bodySmall?.color),
            const SizedBox(width: 6),
            Text('Infos & horaires détaillés',
                style: texts.bodySmall?.copyWith(decoration: TextDecoration.underline)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 16, color: texts.bodySmall?.color),
          ]),
        ),
      ]),
    );
  }

  bool _matchSearch(Plat p) {
    if (_searchQuery.isEmpty) return true;
    return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.description.toLowerCase().contains(_searchQuery.toLowerCase());
  }
}

// SKELETON DE CHARGEMENT
class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SkeletonLoader.image(width: double.infinity, height: 200, radius: BorderRadius.zero),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonLoader.text(width: 180, height: 22),
            const SizedBox(height: AppSpacing.sm),
            SkeletonLoader.text(width: 240, height: 14),
            const SizedBox(height: AppSpacing.lg),
            SkeletonLoader.list(count: 3, itemHeight: 90),
          ]),
        ),
      ],
    );
  }
}

// ÉTAT VIDE — recherche sans résultat
class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    final texts = AppTextStyles.textTheme(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 44, color: texts.bodySmall?.color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            query.isEmpty ? 'Aucun plat disponible' : 'Aucun plat trouvé pour "$query"',
            style: texts.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// STICKY DELEGATE — recherche + TabBar épinglées
class _StickyBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final String searchQuery;

  _StickyBarDelegate({
    required this.tabBar,
    required this.bgColor,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClear,
    required this.searchQuery,
  });

  static const double _searchH = 58.0;

  @override
  double get minExtent => _searchH + tabBar.preferredSize.height;
  @override
  double get maxExtent => _searchH + tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: bgColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 4),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher un plat...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accent, size: 20),
              suffixIcon:
                  searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: onClear) : null,
              filled: true,
              fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: AppRadius.chipRadius, borderSide: BorderSide.none),
            ),
          ),
        ),
        tabBar,
      ]),
    );
  }

  @override
  bool shouldRebuild(_StickyBarDelegate old) => bgColor != old.bgColor || searchQuery != old.searchQuery;
}

// ONGLET AVIS
class _ReviewsTab extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  const _ReviewsTab({required this.restaurantId, required this.restaurantName});
  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  int _userStars = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final reviews = await ReviewService.getReviews(widget.restaurantId);

    int existingStars = 0;
    if (uid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('ratings').doc('${widget.restaurantId}_$uid').get();
        if (doc.exists) existingStars = (doc.data()?['stars'] as int?) ?? 0;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _userStars = existingStars;
      _loading = false;
    });
  }

  Future<void> _submitRating(int stars) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final score = stars * 4;
    HapticFeedback.lightImpact();
    setState(() => _userStars = stars);

    try {
      await FirebaseFirestore.instance.collection('ratings').doc('${widget.restaurantId}_$uid').set({
        'restaurantId': widget.restaurantId,
        'clientUid': uid,
        'stars': stars,
        'score': score,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Merci ! Vous avez donné la note de $score/20'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userStars = 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader.list(count: 4, itemHeight: 84),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final texts = AppTextStyles.textTheme(Theme.of(context).brightness);

    return ListView(
      padding: const EdgeInsets.only(top: 12, left: AppSpacing.md, right: AppSpacing.md, bottom: 100),
      children: [
        if (uid != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(children: [
              Text(
                _userStars == 0 ? 'Notez ${widget.restaurantName}' : 'Votre note : ${_userStars * 4}/20',
                style: texts.titleMedium?.copyWith(color: _userStars == 0 ? null : AppColors.accent),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _userStars;
                  return GestureDetector(
                    onTap: () => _submitRating(i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: filled ? const Color(0xFFFFB020) : AppColors.disabledLight, size: 40)
                          .animate(target: filled ? 1 : 0)
                          .scaleXY(end: 1.15, duration: 120.ms)
                          .then()
                          .scaleXY(end: 1, duration: 100.ms),
                    ),
                  );
                }),
              ),
              if (_userStars > 0) ...[
                const SizedBox(height: 6),
                Text('Appuyez sur une étoile pour modifier', style: texts.labelSmall),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.reviews_outlined, size: 44, color: texts.bodySmall?.color),
                const SizedBox(height: AppSpacing.sm),
                Text("Aucun avis pour l'instant", style: texts.bodyMedium),
              ]),
            ),
          )
        else
          ..._reviews.asMap().entries.map((e) => _ReviewCard(review: e.value)
              .animate()
              .fadeIn(duration: 250.ms, delay: (e.key * 40).ms)
              .slideY(begin: 0.04, end: 0)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.light(brightness),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            backgroundImage: review.clientImageUrl != null ? NetworkImage(review.clientImageUrl!) : null,
            child: review.clientImageUrl == null
                ? Text(review.clientName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.clientName, style: texts.titleSmall),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFB020), size: 13))),
            ]),
          ),
          if (review.createdAt != null)
            Text('${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                style: texts.labelSmall),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.comment, style: texts.bodyMedium),
        ],
      ]),
    );
  }
}

// PLAT CARD
class _PlatCard extends StatelessWidget {
  final Plat plat;
  final Restaurant restaurant;
  final bool isRestaurantOpen;
  const _PlatCard({required this.plat, required this.restaurant, required this.isRestaurantOpen});

  void _addToCart(BuildContext context, CartProvider cart) {
    if (!isRestaurantOpen) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Ce restaurant est fermé pour le moment. Horaires : ${restaurant.openingHours}.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    HapticFeedback.lightImpact();
    final added = cart.addItem(
      name: plat.name,
      price: plat.price,
      img: plat.img,
      restaurantName: restaurant.name,
      restaurantId: restaurant.id,
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(added ? '${plat.name} ajouté !' : 'Maximum 10 articles atteint'),
        backgroundColor: added ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ));
  }

  void _showPlatDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlatDetailPage(
          plat: {
            'name': plat.name,
            'price': plat.priceInt,
            'imageUrl': plat.img,
            'img': plat.img,
            'description': plat.description,
            'category': plat.category,
            'isAvailable': plat.isAvailable,
            'supplements': plat.supplements,
          },
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.light(brightness),
      ),
      // L'image est HORS de l'InkWell pour éviter le conflit d'arène des gestes
      child: Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ImageViewer.open(context, plat.img, 'plat_img_${plat.name}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: AppRadius.imageRadius,
              child: _AnyImage(img: plat.img, width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.card)),
            onTap: () => _showPlatDetail(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plat.name, style: texts.titleMedium),
                const SizedBox(height: 4),
                Text(plat.description, style: texts.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(plat.price, style: AppTextStyles.priceAccent(size: 15)),
                    ),
                  ),
                  Consumer<CartProvider>(
                    builder: (ctx, cart, _) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _addToCart(ctx, cart),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isRestaurantOpen ? AppColors.accent : AppColors.disabledLight,
                          shape: BoxShape.circle,
                          boxShadow: isRestaurantOpen ? AppShadows.strong(brightness) : null,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// WIDGETS RÉUTILISABLES
class _AnyImage extends StatelessWidget {
  final String img;
  final double? width;
  final double? height;
  final BoxFit fit;
  const _AnyImage({required this.img, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: width,
        height: height,
        color: AppColors.accent.withValues(alpha: 0.08),
        child: const Center(child: Icon(Icons.fastfood_rounded, color: AppColors.accent, size: 30)));

    if (img.isEmpty) return fallback;
    if (img.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: img,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => SkeletonLoader.image(width: width, height: height ?? 90, radius: BorderRadius.zero),
        errorWidget: (_, __, ___) => fallback,
      );
    }
    if (img.startsWith('assets/')) {
      return Image.asset(img, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  final Color? color;
  const _CircleBtn({required this.icon, required this.onTap, this.badge, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.imageOverlay.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1)),
          child: badge != null
              ? Badge(
                  label: Text(badge!),
                  backgroundColor: AppColors.accent,
                  child: Icon(icon, color: color ?? Colors.white, size: 20))
              : Icon(icon, color: color ?? Colors.white, size: 20),
        ),
      );
}

class _CartFAB extends StatelessWidget {
  const _CartFAB();

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PanierPage()));
          },
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.shopping_cart_rounded),
          label: Text('${cart.itemCount} art. · ${cart.totalPriceFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        )
            .animate(key: ValueKey(cart.itemCount))
            .scaleXY(begin: 0.85, end: 1, duration: 220.ms, curve: Curves.elasticOut);
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
}
