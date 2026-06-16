// lib/config/env_config.dart
// Lecture centralisée des variables d'environnement (.env via flutter_dotenv)

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Google Maps
  static String get googleMapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Firebase
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseRegion =>
      dotenv.env['FIREBASE_REGION'] ?? 'europe-west1';

  // App
  static String get appName => dotenv.env['APP_NAME'] ?? 'allofoods';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';

  // FedaPay — la clé secrète est gérée côté serveur (Cloud Functions uniquement)
  // Ne PAS exposer FEDAPAY_SECRET_KEY dans l'app mobile.
  static bool get fedaPaySandbox =>
      (dotenv.env['FEDAPAY_SANDBOX'] ?? 'true') == 'true';

  // Commission & tarification
  /// allofoods préléve 5% sur le montant nourriture
  static double get allofoodsCommissionRate =>
      double.tryParse(dotenv.env['allofoods_COMMISSION_RATE'] ?? '0.05') ??
      0.05;

  /// FedaPay préléve 1.8% sur le total (déduit de la part allofoods)
  static double get fedaPayRate =>
      double.tryParse(dotenv.env['FEDAPAY_RATE'] ?? '0.018') ?? 0.018;

  /// Le livreur ne peréoit aucune commission directe (géré comme prestataire)
  static double get driverCommissionRate =>
      double.tryParse(dotenv.env['DRIVER_COMMISSION_RATE'] ?? '0.00') ?? 0.00;

  // Grille de frais de livraison
  static int get deliveryFeeTier1 =>
      int.tryParse(dotenv.env['DELIVERY_FEE_TIER1'] ?? '500') ?? 500;
  static int get deliveryFeeTier2 =>
      int.tryParse(dotenv.env['DELIVERY_FEE_TIER2'] ?? '1000') ?? 1000;
  static int get deliveryFeeTier3 =>
      int.tryParse(dotenv.env['DELIVERY_FEE_TIER3'] ?? '1500') ?? 1500;
  static double get deliveryFeeTier1MaxKm =>
      double.tryParse(dotenv.env['DELIVERY_FEE_TIER1_MAX_KM'] ?? '3') ?? 3;
  static double get deliveryFeeTier2MaxKm =>
      double.tryParse(dotenv.env['DELIVERY_FEE_TIER2_MAX_KM'] ?? '10') ?? 10;
  static double get deliveryFeeTier3MaxKm =>
      double.tryParse(dotenv.env['DELIVERY_FEE_TIER3_MAX_KM'] ?? '15') ?? 15;

  // Supabase Storage
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseBucketProfiles =>
      dotenv.env['SUPABASE_BUCKET_PROFILES'] ?? 'Profiles';
  static String get supabaseBucketLogos =>
      dotenv.env['SUPABASE_BUCKET_LOGOS'] ?? 'Logos';
  static String get supabaseBucketFoods =>
      dotenv.env['SUPABASE_BUCKET_FOODS'] ?? 'Foods';

  // Admin
  static String get adminSecret => dotenv.env['ADMIN_SECRET'] ?? '';
  static String get functionsBaseUrl => dotenv.env['FUNCTIONS_BASE_URL'] ?? '';
}
