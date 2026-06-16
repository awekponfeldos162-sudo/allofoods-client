// lib/pages/restaurant_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';

class RestaurantDetailPage extends StatefulWidget {
  final Restaurant restaurant;
  const RestaurantDetailPage({super.key, required this.restaurant});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  bool _hoursExpanded = true;
  bool _sharing = false;
  GoogleMapController? _mapCtrl;

  Restaurant get r => widget.restaurant;

  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  // Extrait l'heure de fermeture pour "Ouvert jusqu'à HH:MM"
  String get _closingLabel {
    final regex = RegExp(r'[-éàa]\s*(\d{1,2})h(\d{0,2})');
    final match = regex.firstMatch(r.openingHours);
    if (match == null) return r.openingHours;
    final h = match.group(1)!.padLeft(2, '0');
    final m = (match.group(2) ?? '').padLeft(2, '0');
    return '$h:$m';
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

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final mapH = topPad + 270.0;
    final isOpen = r.isCurrentlyOpen;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Carte + AppBar overlay + logo centré ─────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Google Map
                SizedBox(
                  height: mapH,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(r.lat, r.lng),
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('restaurant'),
                        position: LatLng(r.lat, r.lng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(title: r.name),
                      ),
                    },
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (ctrl) {
                      _mapCtrl = ctrl;
                      Future.delayed(const Duration(milliseconds: 700), () {
                        ctrl.showMarkerInfoWindow(const MarkerId('restaurant'));
                      });
                    },
                  ),
                ),

                // Gradient haut (lisibilité boutons AppBar)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: topPad + 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // AppBar : retour + nom + partage + favoris
                Positioned(
                  top: topPad + 8,
                  left: 8,
                  right: 8,
                  child: Row(children: [
                    _CircleBtn(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54)
                            ],
                          ),
                        ),
                      ),
                    ),
                    _CircleBtn(icon: Icons.share_outlined, onTap: _share),
                    const SizedBox(width: 6),
                    Consumer<FavoritesProvider>(
                      builder: (_, favs, __) {
                        final isFav = favs.isFavRestaurant(r.id);
                        return _CircleBtn(
                          icon: isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.white,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            favs.toggleRestaurant(r.id);
                          },
                        );
                      },
                    ),
                  ]),
                ),

                // Logo restaurant centré — chevauche la carte et le contenu
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child:
                          ClipOval(child: _AnyImage(img: r.logoImg, size: 100)),
                    ),
                  ),
                ),
              ],
            ),

            // ── Contenu ───────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(22, 68, 22, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Center(
                    child: Text(
                      r.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Catégories / tags
                  if (r.tags.isNotEmpty)
                    Center(
                      child: Text(
                        r.tags.join(' • '),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.6),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Commande minimum
                  Center(
                    child: Text(
                      'Montant minimum de commande : ${r.minOrder} F',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),

                  const _Sep(),

                  // Adresse
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on_outlined,
                        size: 20, color: Colors.black54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.address,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4),
                      ),
                    ),
                  ]),

                  const _Sep(),

                  // Note
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 22, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (r.reviewCount > 0)
                      Text(
                        ' (${r.reviewCount} notes)',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                  ]),

                  const _Sep(),

                  // Horaires — entête cliquable
                  GestureDetector(
                    onTap: () =>
                        setState(() => _hoursExpanded = !_hoursExpanded),
                    behavior: HitTestBehavior.opaque,
                    child: Row(children: [
                      const Icon(Icons.access_time_outlined,
                          size: 20, color: Colors.black54),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isOpen
                              ? 'Ouvert jusqu\'à $_closingLabel'
                              : 'Fermé · ${r.openingHours}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? Colors.green.shade700
                                : Colors.red.shade600,
                          ),
                        ),
                      ),
                      Icon(
                        _hoursExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.black45,
                      ),
                    ]),
                  ),

                  // Tableau des jours
                  if (_hoursExpanded) ...[
                    const SizedBox(height: 14),
                    ..._days.map((day) {
                      final hours = r.schedule.isNotEmpty
                          ? (r.schedule[day] ?? r.openingHours)
                          : r.openingHours;
                      return _DayRow(day: day, hours: hours);
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String day;
  final String hours;
  const _DayRow({required this.day, required this.hours});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 100,
            child: Text(day,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          Expanded(
            child: Text(
              _formatHours(hours),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
        ]),
      );

  String _formatHours(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.toLowerCase().startsWith('de ')) return raw;
    // "10h00 - 21h00" → "De 10:00 à 21:00"
    final cleaned = raw
        .replaceAllMapped(RegExp(r'h(\d{2})'), (m) => ':${m[1]}')
        .replaceAll(RegExp(r'h(?!\d)'), ':00')
        .trim();
    final parts = cleaned.split(RegExp(r'\s*[-éàa]+\s*'));
    if (parts.length >= 2) return 'De ${parts[0].trim()} à ${parts[1].trim()}';
    return cleaned;
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(height: 1, color: Color(0xFFEEEEEE)),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 20),
        ),
      );
}

class _AnyImage extends StatelessWidget {
  final String img;
  final double size;
  const _AnyImage({required this.img, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: Colors.orange.shade100,
      child: const Center(
          child: Icon(Icons.restaurant, color: Colors.orange, size: 36)),
    );
    if (img.isEmpty) return fallback;
    if (img.startsWith('http')) {
      return Image.network(img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    if (img.startsWith('assets/')) {
      return Image.asset(img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}
