// lib/widgets/premium/skeleton_loader.dart
//
// Remplace CircularProgressIndicator partout où l'app charge des données
// (règle premium #1 : jamais de spinner). Le shimmer donne une preview de
// la forme du contenu à venir → perçu comme plus rapide et plus soigné.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_theme.dart';

class SkeletonLoader extends StatelessWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase(brightness),
      highlightColor: AppColors.shimmerHighlight(brightness),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }

  // ── Bloc générique (rectangle arrondi) ─────────────────────────
  static Widget _block({
    double? width,
    double height = 16,
    BorderRadius radius = const BorderRadius.all(Radius.circular(8)),
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
        child: SizedBox(width: width, height: height),
      );

  /// Une ligne de texte (largeur relative optionnelle, ex: 0.6 = 60% dispo).
  static Widget text({double? width, double height = 14}) =>
      SkeletonLoader(child: _block(width: width, height: height));

  /// Vignette image (restaurant, plat, avatar…).
  static Widget image({
    double? width,
    double height = 160,
    BorderRadius radius = AppRadius.imageRadius,
  }) =>
      SkeletonLoader(child: _block(width: width, height: height, radius: radius));

  /// Carte complète : image + 2 lignes de texte — pour grilles restaurants/plats.
  static Widget card({double height = 220}) => SkeletonLoader(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.cardRadius,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _block(
                  width: double.infinity,
                  height: double.infinity,
                  radius: AppRadius.imageRadius,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _block(width: double.infinity, height: 14),
              const SizedBox(height: AppSpacing.xs),
              _block(width: 90, height: 12),
            ],
          ),
        ),
      );

  /// Liste de [count] lignes façon item de liste (avatar + 2 lignes de texte).
  static Widget list({int count = 4, double itemHeight = 72}) => SkeletonLoader(
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: SizedBox(
                height: itemHeight,
                child: Row(
                  children: [
                    _block(width: 56, height: 56, radius: AppRadius.imageRadius),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _block(width: double.infinity, height: 14),
                          const SizedBox(height: AppSpacing.xs),
                          _block(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
