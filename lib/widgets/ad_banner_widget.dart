// lib/widgets/ad_banner_widget.dart
// Widget bannière publicitaire réutilisable (splash + carousel home)

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdBannerWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final double? height;
  final EdgeInsets margin;
  final BorderRadius borderRadius;

  const AdBannerWidget({
    super.key,
    required this.data,
    this.height,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  // Convertit une couleur hex '#RRGGBB' en Color, avec fallback
  Color _hexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorStart =
        _hexColor(data['bg_color_start'] as String?, const Color(0xFFFF6B00));
    final colorEnd =
        _hexColor(data['bg_color_end'] as String?, const Color(0xFFE65100));
    final imageUrl = (data['image_url'] as String?) ?? '';
    final type = (data['type'] as String?) ?? '';
    final title = (data['title'] as String?) ?? '';
    final subtitle = (data['subtitle'] as String?) ?? '';

    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        // Image de fond via CachedNetworkImage
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        // Overlay sombre si image présente pour lisibilité du texte
        if (imageUrl.isNotEmpty)
          Container(color: Colors.black.withValues(alpha: 0.3)),
        // Contenu texte
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (type != 'banner') ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type == 'promo' ? 'OFFRE SPéCIALE' : 'allofoods',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
