// lib/theme/app_colors.dart
//
// Palette allofoods — règle 60/30/10 :
//   60% fond, 30% structure (cartes/surfaces), 10% accent (orange).
// Toutes les couleurs de l'app doivent venir d'ici — jamais de Color(0x...)
// éparpillé dans les widgets.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Accent (10%) ──────────────────────────────────────────────
  static const Color accent = Color(0xFFFF6B00); // orange premium allofoods
  static const Color accentDark = Color(0xFFCC5600); // pression/hover
  static const Color secondary = Color(0xFF1A1A2E); // bleu nuit élégant

  // ── Statuts ───────────────────────────────────────────────────
  static const Color success = Color(0xFF00C896);
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFB020);
  static const Color info = Color(0xFF3D9CF2);

  // ── Light — 60% fond / 30% structure ─────────────────────────
  // Fond crème premium (au lieu d'un gris neutre) — cohérent avec les
  // maquettes 2026 : chaleureux, met en valeur les cartes blanches.
  static const Color backgroundLight = Color(0xFFFBF5EC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color dividerLight = Color(0xFFEFE6D8);
  static const Color disabledLight = Color(0xFFD1D1D6);

  /// Fond des barres de recherche / champs sur fond crème — légèrement
  /// plus sombre que backgroundLight pour rester visible sans bordure.
  static const Color fieldFillLight = Color(0xFFF3EEE4);
  static const Color fieldFillDark = Color(0xFF232323);

  /// Cercle d'icône de catégorie (accueil) — pêche doux sur fond crème.
  static const Color categoryIconBg = Color(0xFFFDEBDA);

  // ── Dark — 60% fond / 30% structure ──────────────────────────
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color dividerDark = Color(0xFF2C2C2E);
  static const Color disabledDark = Color(0xFF3A3A3C);

  // ── Utilitaires ───────────────────────────────────────────────
  /// Blanc à opacité fixe — utilisé sur boutons/texte au-dessus de l'accent.
  static const Color onAccent = Colors.white;

  /// Overlay sombre pour gradients sur images (headers, cartes restaurant).
  static const Color imageOverlay = Color(0xCC000000); // noir 80%

  static Color shimmerBase(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF232323) : const Color(0xFFE8E8E8);
  static Color shimmerHighlight(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2E2E2E) : const Color(0xFFF5F5F5);
}
