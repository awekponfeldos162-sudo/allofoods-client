// lib/theme/app_radius.dart
//
// Rayons d'arrondi standardisés. Un seul jeu de valeurs pour toute l'app
// afin que boutons/cartes/chips/images restent visuellement cohérents.

import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double button = 14;
  static const double card = 20;
  static const double chip = 100; // pill — toujours "assez grand" pour arrondir totalement
  static const double image = 16;

  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius imageRadius = BorderRadius.all(Radius.circular(image));
}
