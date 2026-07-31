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
        // Overlay dégradé orange — garde une identité "carte de marque"
        // lisible même par-dessus une photo, plutôt qu'un simple voile noir.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                colorStart.withValues(alpha: imageUrl.isNotEmpty ? 0.88 : 1),
                colorEnd.withValues(alpha: imageUrl.isNotEmpty ? 0.55 : 1),
              ],
            ),
          ),
        ),
        // Contenu texte
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type != 'banner') ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      type == 'promo' ? 'OFFRE SPÉCIALE' : 'ALLOFOODS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
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
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Commander',
                      style: TextStyle(
                          color: colorEnd,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: colorEnd, size: 14),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
