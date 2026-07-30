// lib/widgets/premium/premium_card.dart
//
// Remplace Container/Card standard — ombre douce (jamais de bordure épaisse,
// règle #2), radius 20px, retour tactile optionnel si [onTap] est fourni.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'premium_interactions.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  /// Niveau d'ombre — 'light' (défaut), 'medium', 'strong' (teintée orange).
  final CardElevationLevel elevation;

  /// Active un flou d'arrière-plan (glassmorphism léger) — utile pour les
  /// cartes superposées à une image (ex: header restaurant).
  final bool blur;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.elevation = CardElevationLevel.light,
    this.blur = false,
  });

  List<BoxShadow> _shadow(Brightness b) => switch (elevation) {
        CardElevationLevel.light => AppShadows.light(b),
        CardElevationLevel.medium => AppShadows.medium(b),
        CardElevationLevel.strong => AppShadows.strong(b),
      };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = color ??
        (brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.surfaceLight);

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: blur ? bg.withValues(alpha: 0.75) : bg,
        borderRadius: AppRadius.cardRadius,
      ),
      child: child,
    );

    // BackdropFilter coûte une save-layer — on ne l'applique que si demandé.
    Widget content = !blur
        ? ClipRRect(borderRadius: AppRadius.cardRadius, child: inner)
        : ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: inner,
            ),
          );

    content = DecoratedBox(
      decoration: BoxDecoration(borderRadius: AppRadius.cardRadius, boxShadow: _shadow(brightness)),
      child: content,
    );

    if (onTap == null) return content;
    return TapScale(onTap: onTap, pressedScale: 0.98, child: content);
  }
}

enum CardElevationLevel { light, medium, strong }
