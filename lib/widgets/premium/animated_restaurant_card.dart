// lib/widgets/premium/animated_restaurant_card.dart
//
// Carte restaurant premium pour la homepage / listes — image Hero,
// gradient overlay, badge ouvert/fermé, note animée à l'apparition.
//
// IMPORTANT : la page de détail doit envelopper son image d'en-tête dans
// un Hero(tag: AnimatedRestaurantCard.heroTag(restaurant.id), ...) pour que
// la transition Hero fonctionne au tap.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/restaurant_model.dart';
import '../../theme/app_theme.dart';
import 'premium_card.dart';
import 'skeleton_loader.dart';

class AnimatedRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  /// Si fourni (avec [onToggleFavorite]), affiche un bouton cœur en haut à
  /// droite de l'image.
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Hauteur de l'image — 150 par défaut, réductible pour les listes denses.
  final double imageHeight;

  const AnimatedRestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.isFavorite,
    this.onToggleFavorite,
    this.imageHeight = 150,
  });

  static String heroTag(String restaurantId) => 'restaurant-image-$restaurantId';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    final isOpen = restaurant.isActive;

    return PremiumCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      elevation: CardElevationLevel.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image + overlay + badges ──────────────────────────
          SizedBox(
            height: imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: heroTag(restaurant.id),
                  child: CachedNetworkImage(
                    imageUrl: restaurant.coverImg,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        SkeletonLoader.image(height: imageHeight, radius: BorderRadius.zero),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.dividerLight,
                      child: const Icon(Icons.restaurant, color: AppColors.textSecondaryLight, size: 32),
                    ),
                  ),
                ),
                // Gradient bas — lisibilité si texte superposé plus tard
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.imageOverlay.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                ),
                // Badge ouvert / fermé
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _Badge(
                    label: isOpen ? 'Ouvert' : 'Fermé',
                    color: isOpen ? AppColors.success : AppColors.error,
                  ),
                ),
                // Badge promo
                if (restaurant.hasActivePromo)
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _Badge(label: '🔥 Promo', color: AppColors.accent),
                  ),
                // Bouton favori
                if (onToggleFavorite != null)
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _FavoriteButton(
                      isFavorite: isFavorite ?? false,
                      onTap: onToggleFavorite!,
                    ),
                  ),
              ],
            ),
          ),

          // ── Infos ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: texts.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                if (restaurant.tags.isNotEmpty)
                  Text(
                    restaurant.tags.take(3).join(' · '),
                    style: texts.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _RatingChip(rating: restaurant.rating, reviewCount: restaurant.reviewCount),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.access_time_rounded, size: 14, color: texts.bodySmall?.color),
                    const SizedBox(width: 2),
                    Text('${restaurant.deliveryTime} min', style: texts.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.imageOverlay.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? AppColors.error : Colors.white,
          size: 16,
        ),
      )
          .animate(target: isFavorite ? 1 : 0)
          .scaleXY(begin: 1, end: 1.15, duration: 150.ms, curve: Curves.easeOut)
          .then()
          .scaleXY(end: 1, duration: 100.ms),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: AppRadius.chipRadius),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
}

class _RatingChip extends StatelessWidget {
  final double rating;
  final int reviewCount;
  const _RatingChip({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
        const SizedBox(width: 2),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : '—',
          style: AppTextStyles.price(Theme.of(context).brightness, size: 12, weight: FontWeight.w600),
        ),
        if (reviewCount > 0)
          Text(' ($reviewCount)', style: Theme.of(context).textTheme.bodySmall),
      ],
    ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.85, end: 1, curve: Curves.easeOut);
  }
}
