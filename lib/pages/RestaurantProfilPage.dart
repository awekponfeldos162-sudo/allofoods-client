// lib/pages/RestaurantProfilPage.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final allCats = [
      ...(cats.isEmpty ? ['Menu'] : cats),
      'Avis'
    ];
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
    if (_loading || _tabController == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
            backgroundColor: Colors.white, foregroundColor: Colors.black87),
        body: const Center(
            child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      if (cart.items.isNotEmpty &&
          cart.restaurantId.isNotEmpty &&
          cart.restaurantId != r.id) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '?? Votre panier contient des articles de ${cart.restaurantName}. '
              'Ajouter ici videra votre panier.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    if (!r.isActive) {
      return Scaffold(
        appBar: AppBar(
            title: Text(r.name),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.store_mall_directory_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Restaurant temporairement indisponible',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Ce restaurant n'est pas encore disponible.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500)),
            ]),
          ),
        ),
      );
    }

    final isOpen = r.isCurrentlyOpen;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (ctx, _) => [
          // AppBar responsive : transparent sur image, blanc quand scrollé
          SliverAppBar(
            pinned: true,
            expandedHeight: _coverHeight,
            backgroundColor: _collapsed ? Colors.white : Colors.transparent,
            foregroundColor: _collapsed ? Colors.black87 : Colors.white,
            elevation: _collapsed ? 1 : 0,
            shadowColor: Colors.black26,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: _collapsed
                ? Text(r.name,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis)
                : null,
            leading: _collapsed
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(ctx),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: _CircleBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(ctx)),
                  ),
            actions: _collapsed
                ? [
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.black87),
                      onPressed: _share,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.black87),
                      onPressed: () {
                        _scrollCtrl.animateTo(_coverHeight,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                    ),
                    Consumer<FavoritesProvider>(
                      builder: (_, favs, __) {
                        final isFav = favs.isFavRestaurant(r.id);
                        return IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.black87,
                          ),
                          onPressed: () => favs.toggleRestaurant(r.id),
                        );
                      },
                    ),
                    Consumer<CartProvider>(
                      builder: (ctx2, cart, _) => cart.itemCount > 0
                          ? IconButton(
                              icon: Badge(
                                label: Text('${cart.itemCount}'),
                                child: const Icon(Icons.shopping_cart_outlined,
                                    color: Colors.black87),
                              ),
                              onPressed: () => Navigator.push(
                                  ctx2,
                                  MaterialPageRoute(
                                      builder: (_) => const PanierPage())),
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
                            icon:
                                isFav ? Icons.favorite : Icons.favorite_border,
                            onTap: () => favs.toggleRestaurant(r.id),
                            color: isFav ? Colors.red : Colors.white,
                          ),
                        );
                      },
                    ),
                    Consumer<CartProvider>(
                      builder: (ctx2, cart, _) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CircleBtn(
                          icon: Icons.shopping_cart_outlined,
                          badge:
                              cart.itemCount > 0 ? '${cart.itemCount}' : null,
                          onTap: () => Navigator.push(
                              ctx2,
                              MaterialPageRoute(
                                  builder: (_) => const PanierPage())),
                        ),
                      ),
                    ),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverOnly(ctx, isOpen),
            ),
          ),

          // Infos restaurant (scroll avec la page)
          SliverToBoxAdapter(child: _buildRestaurantInfo(ctx, isOpen)),
          // Recherche + TabBar (épinglées ensemble)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBarDelegate(
              tabBar: TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.orange,
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            final plats = r.plats
                .where((p) => p.category == cat && _matchSearch(p))
                .toList();
            return ListView.builder(
              padding: const EdgeInsets.only(
                  top: 8, left: 14, right: 14, bottom: 100),
              itemCount: plats.isEmpty ? 1 : plats.length,
              itemBuilder: (context, i) {
                if (plats.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Aucun plat trouvé',
                          style: TextStyle(color: Colors.grey)),
                    ])),
                  );
                }
                return _PlatCard(
                    plat: plats[i], restaurant: r, isRestaurantOpen: isOpen);
              },
            );
          }).toList(),
        ),
      ),
      floatingActionButton: _CartFAB(),
    );
  }

  // Image couverture seule (utilisée dans FlexibleSpaceBar)
  Widget _buildCoverOnly(BuildContext context, bool isOpen) {
    return Stack(fit: StackFit.expand, children: [
      _AnyImage(img: r.coverImg, fit: BoxFit.cover),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.15),
              Colors.black.withValues(alpha: 0.65),
            ],
          ),
        ),
      ),
      // Badge ouvert/fermé
      Positioned(
        top: MediaQuery.of(context).padding.top + 56,
        left: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.green.withValues(alpha: 0.85)
                : Colors.red.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isOpen ? Icons.circle : Icons.do_not_disturb_on_outlined,
              size: 8,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(isOpen ? 'Ouvert' : 'Fermé',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
      // Nom + style en bas
      Positioned(
        bottom: 16,
        left: 16,
        right: 80,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
          const SizedBox(height: 3),
          Text(r.style,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
        ]),
      ),
      // Logo
      Positioned(
        bottom: 12,
        right: 16,
        child: GestureDetector(
          onTap: () => ImageViewer.open(context, r.logoImg, 'logo_${r.id}'),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8)
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: _AnyImage(
                    img: r.logoImg, width: 56, height: 56, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // Infos restaurant (tags, stats, adresse, description…)
  Widget _buildRestaurantInfo(BuildContext context, bool isOpen) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: r.tags
              .map((tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _StatChip(
              icon: Icons.star,
              color: Colors.amber,
              label: r.rating.toStringAsFixed(1)),
          const SizedBox(width: 14),
          _StatChip(
              icon: Icons.delivery_dining,
              color: Colors.blue,
              label: '${r.deliveryTime} min'),
          const SizedBox(width: 14),
          _StatChip(
              icon: Icons.shopping_bag_outlined,
              color: Colors.green,
              label: 'Min ${r.minOrder} FCFA'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 3),
          Expanded(
              child: Text(r.address,
                  style: const TextStyle(fontSize: 11, color: Colors.grey))),
          const Icon(Icons.access_time, size: 14, color: Colors.grey),
          const SizedBox(width: 3),
          Text(r.openingHours,
              style: TextStyle(
                  fontSize: 11,
                  color: isOpen ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(r.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, color: Colors.black87, height: 1.4)),
        const SizedBox(height: 8),
        if (!isOpen)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Ce restaurant est actuellement fermé. '
                    'Commandes autorisées uniquement durant les heures ouvrables.',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
              ),
            ]),
          )
        else
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.phone_outlined, size: 14),
            label: Text(r.phone, style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(height: 10),
        // Bouton infos & horaires détaillés
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RestaurantDetailPage(restaurant: r)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 15, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Infos & horaires détaillés',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    decoration: TextDecoration.underline)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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

// STICKY DELEGATE é recherche + TabBar épinglées
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bgColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher un plat...',
              prefixIcon:
                  const Icon(Icons.search, color: Colors.orange, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClear)
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        tabBar,
      ]),
    );
  }

  @override
  bool shouldRebuild(_StickyBarDelegate old) =>
      bgColor != old.bgColor || searchQuery != old.searchQuery;
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
        final doc = await FirebaseFirestore.instance
            .collection('ratings')
            .doc('${widget.restaurantId}_$uid')
            .get();
        if (doc.exists) {
          existingStars = (doc.data()?['stars'] as int?) ?? 0;
        }
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
    setState(() => _userStars = stars);

    try {
      await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${widget.restaurantId}_$uid')
          .set({
        'restaurantId': widget.restaurantId,
        'clientUid': uid,
        'stars': stars,
        'score': score,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Merci ! Vous avez donné la note de $score/20'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userStars = 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.orange));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.only(top: 12, left: 14, right: 14, bottom: 100),
      children: [
        if (uid != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(children: [
              Text(
                _userStars == 0
                    ? 'Notez ${widget.restaurantName}'
                    : 'Votre note : ${_userStars * 4}/20',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _userStars == 0 ? Colors.black87 : Colors.orange,
                ),
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
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: filled ? Colors.amber : Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              if (_userStars > 0) ...[
                const SizedBox(height: 6),
                Text('Appuyez sur une étoile pour modifier',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.reviews_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text("Aucun avis pour l'instant",
                    style: TextStyle(color: Colors.grey)),
              ]),
            ),
          )
        else
          ..._reviews.map((rev) => _ReviewCard(review: rev)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: review.clientImageUrl != null
                ? NetworkImage(review.clientImageUrl!)
                : null,
            child: review.clientImageUrl == null
                ? Text(review.clientName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.clientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 13))),
            ]),
          ),
          if (review.createdAt != null)
            Text(
                '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.comment,
              style: const TextStyle(fontSize: 13, height: 1.4)),
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
  const _PlatCard(
      {required this.plat,
      required this.restaurant,
      required this.isRestaurantOpen});

  void _addToCart(BuildContext context, CartProvider cart) {
    if (!isRestaurantOpen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ce restaurant est actuellement fermé. Commandes autorisées uniquement durant les heures ouvrables.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
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
        content: Text(
            added ? '${plat.name} ajouté !' : 'Maximum 10 articles atteint'),
        backgroundColor: added ? Colors.green.shade600 : Colors.orange.shade700,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      // L'image est HORS de l'InkWell pour éviter le conflit d'arène des gestes
      child: Row(children: [
        // Image é tap = visualiseur plein écran
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ImageViewer.open(context, plat.img, 'plat_img_${plat.name}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _AnyImage(
                  img: plat.img, width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
        ),
        // Infos + bouton é tap = feuille détail
        Expanded(
          child: InkWell(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(18)),
            onTap: () => _showPlatDetail(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plat.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(plat.description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(plat.price,
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                          ),
                          Consumer<CartProvider>(
                            builder: (ctx, cart, _) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _addToCart(ctx, cart),
                              child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: isRestaurantOpen
                                          ? Colors.orange
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 18)),
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

// WIDGETS RéUTILISABLES
class _AnyImage extends StatelessWidget {
  final String img;
  final double? width;
  final double? height;
  final BoxFit fit;
  const _AnyImage(
      {required this.img, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: width,
        height: height,
        color: Colors.orange.shade100,
        child: const Center(
            child: Icon(Icons.fastfood, color: Colors.orange, size: 30)));

    if (img.isEmpty) return fallback;
    if (img.startsWith('http')) {
      return Image.network(img,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback);
    }
    if (img.startsWith('assets/')) {
      return Image.asset(img,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  final Color? color;
  const _CircleBtn(
      {required this.icon, required this.onTap, this.badge, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1)),
          child: badge != null
              ? Badge(
                  label: Text(badge!),
                  child: Icon(icon, color: color ?? Colors.white, size: 20))
              : Icon(icon, color: color ?? Colors.white, size: 20),
        ),
      );
}

class _CartFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PanierPage())),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.shopping_cart),
          label: Text('${cart.itemCount} art. é ${cart.totalPriceFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatChip(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
}
