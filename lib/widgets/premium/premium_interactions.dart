// lib/widgets/premium/premium_interactions.dart
//
// Interaction tactile partagée par PremiumButton, PremiumCard et
// AnimatedRestaurantCard : scale 0.97 → 1.0 au tap + haptic feedback.
// Centralisé ici pour ne pas dupliquer la même AnimationController×3.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Enrobe [child] d'un effet d'appui premium : léger scale-down pendant
/// l'appui (relâché en spring vers 1.0) + vibration légère au tap.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final HapticFeedbackType haptic;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.haptic = HapticFeedbackType.light,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

enum HapticFeedbackType { light, selection, none }

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.none:
        break;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap == null ? null : _handleTap,
      child: widget.child
          .animate(target: _pressed ? 1 : 0)
          .scaleXY(end: widget.pressedScale, duration: 120.ms, curve: Curves.easeOut),
    );
  }
}
