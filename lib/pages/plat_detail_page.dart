// lib/pages/plat_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../l10n/app_localizations.dart';

class PlatDetailPage extends StatefulWidget {
  final Map<String, dynamic> plat;
  final String restaurantId;
  final String restaurantName;

  const PlatDetailPage({
    super.key,
    required this.plat,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<PlatDetailPage> createState() => _PlatDetailPageState();
}

class _PlatDetailPageState extends State<PlatDetailPage> {
  late List<Set<int>> _selected;
  late List<bool> _expanded;
  final _instructionsCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isFav = false;
  bool _favLoading = false;
  bool _collapsed = false;
  bool _sharing = false;

  static const double _expandedHeight = 300;

  @override
  void initState() {
    super.initState();
    final g = _groups;
    _selected = List.generate(g.length, (_) => <int>{});
    _expanded = List.generate(g.length, (_) => true);
    _checkFav();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final isCollapsed =
        _scrollCtrl.hasClients && _scrollCtrl.offset > _expandedHeight - kToolbarHeight - 10;
    if (isCollapsed != _collapsed) setState(() => _collapsed = isCollapsed);
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final link = 'https://allofoods.netlify.app/restaurant/${widget.restaurantId}';
    final msg = '🍽️ Je vous recommande *$_name* chez *${widget.restaurantName}* sur AlloFoods !\n\n'
        '💰 $_basePrice F\n\n'
        '👉 $link';
    try {
      if (_img.startsWith('http')) {
        final res = await http.get(Uri.parse(_img));
        if (res.statusCode == 200) {
          final tmp = File(
              '${Directory.systemTemp.path}/allofoods_dish_${_name.replaceAll(' ', '_')}.jpg');
          await tmp.writeAsBytes(res.bodyBytes);
          await Share.shareXFiles([XFile(tmp.path)], text: msg, subject: _name);
          return;
        }
      }
      await Share.share(msg, subject: _name);
    } catch (_) {
      await Share.share(msg, subject: _name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String get _name => widget.plat['name'] as String? ?? '';
  String get _desc => widget.plat['description'] as String? ?? '';
  int get _basePrice => (widget.plat['price'] as num?)?.toInt() ?? 0;
  String get _img =>
      widget.plat['imageUrl'] as String? ?? widget.plat['img'] as String? ?? '';
  bool get _available => widget.plat['isAvailable'] as bool? ?? true;

  List<Map<String, dynamic>> get _groups {
    final raw = widget.plat['supplements'] as List? ?? [];
    return raw.map((g) => Map<String, dynamic>.from(g as Map)).toList();
  }

  int get _extraPrice {
    int extra = 0;
    final groups = _groups;
    for (int gi = 0; gi < groups.length && gi < _selected.length; gi++) {
      final items = groups[gi]['items'] as List? ?? [];
      for (final idx in _selected[gi]) {
        if (idx < items.length) {
          extra += (Map<String, dynamic>.from(items[idx] as Map)['price'] as num?)
                  ?.toInt() ??
              0;
        }
      }
    }
    return extra;
  }

  int get _totalPrice => _basePrice + _extraPrice;
  String get _favKey => '${widget.restaurantId}__$_name';

  Future<void> _checkFav() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final favs =
        (snap.data()?['favoriteDishes'] as List?)?.cast<String>() ?? [];
    setState(() => _isFav = favs.contains(_favKey));
  }

  Future<void> _toggleFav() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _favLoading = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      if (_isFav) {
        await ref.update({'favoriteDishes': FieldValue.arrayRemove([_favKey])});
      } else {
        await ref.update({'favoriteDishes': FieldValue.arrayUnion([_favKey])});
      }
      if (mounted) setState(() => _isFav = !_isFav);
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  void _toggleItem(int gi, int ii, String type) {
    setState(() {
      if (type == 'single') {
        _selected[gi] = _selected[gi].contains(ii) ? {} : {ii};
      } else {
        if (_selected[gi].contains(ii)) {
          _selected[gi].remove(ii);
        } else {
          _selected[gi].add(ii);
        }
      }
    });
  }

  void _addToCart() {
    if (!_available) return;
    context.read<CartProvider>().addItem(
          name: _name,
          price: '$_totalPrice',
          img: _img,
          restaurantName: widget.restaurantName,
          restaurantId: widget.restaurantId,
        );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).addedToCart(_name)),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // ── Photo couverture + AppBar responsive ─────────────────────────
          SliverAppBar(
            expandedHeight: _expandedHeight,
            pinned: true,
            backgroundColor: _collapsed ? Colors.white : Colors.transparent,
            foregroundColor: _collapsed ? Colors.black87 : Colors.white,
            elevation: _collapsed ? 1 : 0,
            shadowColor: Colors.black26,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,

            // Titre visible uniquement en mode collapsed
            title: _collapsed
                ? Text(_name,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis)
                : null,

            // Bouton retour
            leading: _collapsed
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: _CircleBtn(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),

            // Actions : partage + favori
            actions: _collapsed
                ? [
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.black87),
                      onPressed: _share,
                    ),
                    _favLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.orange),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              _isFav ? Icons.favorite : Icons.favorite_border,
                              color: _isFav ? Colors.red : Colors.black87,
                            ),
                            onPressed: _toggleFav,
                          ),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _favLoading
                          ? Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white),
                              ),
                            )
                          : _CircleBtn(
                              icon: _isFav
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _isFav ? Colors.red : Colors.white,
                              onTap: _toggleFav,
                            ),
                    ),
                  ],

            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                // Image
                if (_img.startsWith('http'))
                  Image.network(
                    _img,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            color: Colors.orange.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.orange, strokeWidth: 2),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => _imgFallback(),
                  )
                else if (_img.startsWith('assets/'))
                  Image.asset(
                    _img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgFallback(),
                  )
                else
                  _imgFallback(),

                // Gradient haut → transparent (pour les boutons flottants)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Gradient bas → fond page (transition douce vers contenu)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFFF5F5F5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge indisponible
                if (!_available)
                  Positioned(
                    top: topPad + 60,
                    left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context).dishUnavailable,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),

          ),

          // ── Contenu ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + prix
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '$_basePrice F',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Restaurant
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Row(children: [
                      Icon(Icons.store_outlined,
                          size: 13, color: Colors.orange.shade400),
                      const SizedBox(width: 4),
                      Text(widget.restaurantName,
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade600,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),

                  // Description
                  if (_desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        _desc,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Sections suppléments ──────────────────────────────────────────
          if (groups.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                children: List.generate(groups.length, (gi) {
                  final group = groups[gi];
                  final groupName = group['name'] as String? ?? '';
                  final type = group['type'] as String? ?? 'single';
                  final maxChoices = (group['maxChoices'] as num?)?.toInt() ?? 1;
                  final items = group['items'] as List? ?? [];
                  final subtitle = type == 'single'
                      ? 'Choisissez 1 option'
                      : 'Jusqu\'à $maxChoices choix';
                  final isExpanded =
                      gi < _expanded.length ? _expanded[gi] : true;
                  final hasSelection = gi < _selected.length &&
                      _selected[gi].isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête groupe
                        InkWell(
                          onTap: () =>
                              setState(() => _expanded[gi] = !isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(groupName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        if (hasSelection) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle),
                                          ),
                                        ],
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(subtitle,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500)),
                                    ]),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.orange.shade400,
                              ),
                            ]),
                          ),
                        ),

                        Divider(height: 1, color: Colors.grey.shade100),

                        // Éléments du groupe
                        if (isExpanded)
                          ...List.generate(items.length, (ii) {
                            final item =
                                Map<String, dynamic>.from(items[ii] as Map);
                            final itemName = item['name'] as String? ?? '';
                            final itemPrice =
                                (item['price'] as num?)?.toInt() ?? 0;
                            final isSelected = gi < _selected.length &&
                                _selected[gi].contains(ii);

                            return InkWell(
                              onTap: () => _toggleItem(gi, ii, type),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.orange.withValues(alpha: 0.04)
                                      : Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade100),
                                  ),
                                ),
                                child: Row(children: [
                                  if (type == 'single')
                                    _RadioDot(selected: isSelected)
                                  else
                                    _PlusToggle(selected: isSelected),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(itemName,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: isSelected
                                                ? Colors.black87
                                                : Colors.black87)),
                                  ),
                                  if (itemPrice > 0)
                                    Text('+$itemPrice F',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Colors.orange
                                                : Colors.grey.shade500,
                                            fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ),
            ),

          // ── Instructions marchand ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.notes_outlined,
                        size: 16, color: Colors.orange.shade400),
                    const SizedBox(width: 6),
                    const Text('Instructions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Ajouter des instructions pour le marchand (optionnel)',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.orange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),

      // ── Bouton ajouter au panier ──────────────────────────────────────────
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
        child: ElevatedButton(
          onPressed: _available ? _addToCart : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _available ? Colors.orange : Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            elevation: _available ? 3 : 0,
            shadowColor: Colors.orange.withValues(alpha: 0.4),
          ),
          child: Text(
            _available
                ? 'Ajouter au panier  •  $_totalPrice F'
                : 'Plat indisponible',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
        color: Colors.orange.shade100,
        child: Center(
          child: Icon(Icons.fastfood_outlined,
              size: 72, color: Colors.orange.shade300),
        ),
      );
}

// ─── Widgets utilitaires ────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

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
                color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      );
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade400,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                ),
              )
            : null,
      );
}

class _PlusToggle extends StatelessWidget {
  final bool selected;
  const _PlusToggle({required this.selected});

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade400,
            width: 1.5,
          ),
          color: selected
              ? Colors.orange.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Icon(
          selected ? Icons.check : Icons.add,
          size: 16,
          color: selected ? Colors.orange : Colors.grey.shade500,
        ),
      );
}
