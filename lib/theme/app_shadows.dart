// lib/theme/app_shadows.dart
//
// Ombres douces premium — remplacent les bordures épaisses. Les valeurs
// sombres utilisent un noir plus opaque car les ombres sont moins visibles
// sur fond déjà sombre.

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  static List<BoxShadow> light(Brightness b) => [
        BoxShadow(
          color: (b == Brightness.dark ? Colors.black : Colors.black)
              .withValues(alpha: b == Brightness.dark ? 0.24 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> medium(Brightness b) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.dark ? 0.32 : 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Ombre "forte" teintée orange — réservée aux éléments d'accent
  /// (bouton principal, carte mise en avant).
  static List<BoxShadow> strong(Brightness b) => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: b == Brightness.dark ? 0.28 : 0.15),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];
}
