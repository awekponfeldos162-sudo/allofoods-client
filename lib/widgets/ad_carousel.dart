// lib/widgets/ad_carousel.dart
// Carousel de publicités home_top é pleine largeur + ombre portée
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_banner_widget.dart';

// Hauteur commune du carousel
const double _kCarouselHeight = 190;

class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  int _current = 0;
  late PageController _ctrl;
  Timer? _timer;
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('advertisements')
        .where('position', isEqualTo: 'home_top')
        .where('is_active', isEqualTo: true)
        .where('end_date', isGreaterThan: Timestamp.now())
        .orderBy('end_date')
        .orderBy('priority')
        .limit(5)
        .snapshots();

    _ctrl = PageController(viewportFraction: 0.92);

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _handleAction(String? type, String? value) {
    if (type == null || value == null || value.isEmpty) return;
    try {
      switch (type) {
        case 'url':
          launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
          break;
        case 'promo_code':
          Clipboard.setData(ClipboardData(text: value));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Code "$value" copié !'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          }
          break;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _DefaultBanner();
        }

        final ads = snap.data!.docs;

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(children: [
            SizedBox(
              height: _kCarouselHeight,
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) {
                  if (ads.isNotEmpty) {
                    setState(() => _current = i % ads.length);
                  }
                },
                itemBuilder: (_, i) {
                  final idx = i % ads.length;
                  final doc = ads[idx];
                  final data = doc.data() as Map<String, dynamic>;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      try {
                        doc.reference
                            .update({'clicks': FieldValue.increment(1)});
                      } catch (_) {}
                      _handleAction(
                        data['action_type'] as String?,
                        data['action_value'] as String?,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 18,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AdBannerWidget(data: data),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Dots animés
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                ads.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: (_current % ads.length) == i ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: (_current % ads.length) == i
                        ? Colors.orange
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}

// Bannière statique allofoods (aucune pub active)
class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Container(
        height: _kCarouselHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFE64A19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.38),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(children: [
          // Cercles décoratifs en arrière-plan
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'allofoods',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Livraison rapide\né Cotonou',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Commandez vos plats préférés',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
