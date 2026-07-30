// lib/widgets/premium/premium_button.dart
//
// CTA principal de l'app — remplace ElevatedButton pour toute action
// importante (payer, commander, confirmer...). Gradient orange, retour
// tactile (scale + haptic), état de chargement sans spinner (règle #1).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'premium_interactions.dart';

class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;
  final double? width;

  /// Variante secondaire (outline sombre) — pour actions non-principales
  /// qui doivent quand même garder le style premium (ex: "Annuler").
  final bool outlined;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 56,
    this.width = double.infinity,
    this.outlined = false,
  });

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return TapScale(
      onTap: _enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonRadius,
          gradient: outlined
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _enabled
                      ? [AppColors.accent, AppColors.accentDark]
                      : [
                          AppColors.disabledLight,
                          AppColors.disabledLight,
                        ],
                ),
          color: outlined ? Colors.transparent : null,
          border: outlined ? Border.all(color: AppColors.accent, width: 1.5) : null,
          boxShadow: (_enabled && !outlined) ? AppShadows.strong(brightness) : null,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? const _LoadingDots(key: ValueKey('loading'))
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: outlined ? AppColors.accent : Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.textTheme(brightness).titleMedium?.copyWith(
                              color: outlined ? AppColors.accent : Colors.white,
                            ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Indicateur de chargement "3 points" — alternative premium au spinner.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: const _Dot()
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 400.ms, delay: (i * 150).ms)
              .then()
              .fadeOut(duration: 400.ms),
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
}
