// lib/theme/app_text_styles.dart
//
// Typographie allofoods :
//   - Titres        → Plus Jakarta Sans (Bold / SemiBold)
//   - Corps de texte → Inter (Regular / Medium)
//   - Prix/chiffres  → Outfit (SemiBold) — remplace "SF Pro Rounded"
//     indisponible via Google Fonts ; Outfit a le même esprit arrondi/premium.
//
// Les polices sont chargées via google_fonts (pas de .ttf à gérer soi-même).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// TextTheme complet, à injecter dans ThemeData.textTheme.
  /// Toute la hiérarchie Material (Text() sans style explicite) hérite
  /// automatiquement de la bonne police + couleur selon le thème actif.
  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    TextStyle jakarta(double size, FontWeight w, Color c, {double? height, double? spacing}) =>
        GoogleFonts.plusJakartaSans(
            fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: spacing);

    TextStyle inter(double size, FontWeight w, Color c, {double? height}) =>
        GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: height);

    return TextTheme(
      // Titres — Plus Jakarta Sans
      displayLarge: jakarta(34, FontWeight.w700, primary, height: 1.15),
      displayMedium: jakarta(28, FontWeight.w700, primary, height: 1.18),
      displaySmall: jakarta(24, FontWeight.w700, primary, height: 1.2),
      headlineLarge: jakarta(22, FontWeight.w700, primary, height: 1.2),
      headlineMedium: jakarta(20, FontWeight.w600, primary, height: 1.25),
      headlineSmall: jakarta(18, FontWeight.w600, primary, height: 1.25),
      titleLarge: jakarta(16, FontWeight.w600, primary, height: 1.3),
      titleMedium: jakarta(15, FontWeight.w600, primary, height: 1.3),
      titleSmall: jakarta(13, FontWeight.w600, primary, height: 1.3),

      // Corps — Inter
      bodyLarge: inter(16, FontWeight.w400, primary, height: 1.5),
      bodyMedium: inter(14, FontWeight.w400, primary, height: 1.5),
      bodySmall: inter(12, FontWeight.w400, secondary, height: 1.4),
      labelLarge: inter(14, FontWeight.w500, primary, height: 1.3),
      labelMedium: inter(12, FontWeight.w500, secondary, height: 1.3),
      labelSmall: inter(11, FontWeight.w500, secondary, height: 1.3),
    );
  }

  /// Style dédié aux prix/chiffres (Outfit) — à utiliser explicitement,
  /// n'existe pas de slot Material dédié aux nombres.
  static TextStyle price(
    Brightness brightness, {
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    final defaultColor =
        brightness == Brightness.dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color ?? defaultColor);
  }

  /// Variante accentuée (orange) du style prix — total à payer, promo, etc.
  static TextStyle priceAccent({double size = 18, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: AppColors.accent);
}
