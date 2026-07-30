// lib/widgets/premium/order_status_bar.dart
//
// Stepper horizontal animé pour le suivi de commande (TrackingPage).
// Volontairement générique/découplé du vocabulaire de statuts Firestore
// ('pending', 'preparing', ...) : l'appelant fournit ses propres steps.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class OrderStatusStep {
  final String key;
  final String label;
  final IconData icon;
  const OrderStatusStep({required this.key, required this.label, required this.icon});
}

class OrderStatusBar extends StatelessWidget {
  final List<OrderStatusStep> steps;
  final String currentKey;

  const OrderStatusBar({super.key, required this.steps, required this.currentKey});

  int get _currentIndex {
    final i = steps.indexWhere((s) => s.key == currentKey);
    return i == -1 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final texts = AppTextStyles.textTheme(brightness);
    final currentIndex = _currentIndex;
    final current = steps[currentIndex];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Segment de ligne entre deux étapes
              final stepIndex = i ~/ 2;
              final done = stepIndex < currentIndex;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success
                        : (brightness == Brightness.dark ? AppColors.dividerDark : AppColors.dividerLight),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }
            final stepIndex = i ~/ 2;
            return _StepDot(
              step: steps[stepIndex],
              state: stepIndex < currentIndex
                  ? _DotState.done
                  : stepIndex == currentIndex
                      ? _DotState.active
                      : _DotState.upcoming,
              brightness: brightness,
            );
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            current.label,
            key: ValueKey(current.key),
            style: texts.titleMedium?.copyWith(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}

enum _DotState { done, active, upcoming }

class _StepDot extends StatelessWidget {
  final OrderStatusStep step;
  final _DotState state;
  final Brightness brightness;

  const _StepDot({required this.step, required this.state, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (state) {
      _DotState.done => AppColors.success,
      _DotState.active => AppColors.accent,
      _DotState.upcoming =>
        brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.dividerLight,
    };
    final Color iconColor = switch (state) {
      _DotState.done || _DotState.active => Colors.white,
      _DotState.upcoming =>
        brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    };

    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: state == _DotState.active
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Icon(state == _DotState.done ? Icons.check_rounded : step.icon, size: 18, color: iconColor),
    );

    // Pulsation continue uniquement sur l'étape active — signale "en cours".
    if (state == _DotState.active) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(end: 1.12, duration: 700.ms, curve: Curves.easeInOut);
    }

    return dot;
  }
}
