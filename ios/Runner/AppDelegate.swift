import UIKit
import Flutter
import GoogleMaps  // ← Google Maps iOS SDK

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ── Clé Google Maps ──────────────────────────
    // Remplace TA_CLE_GOOGLE_MAPS_ICI par ta vraie clé
    // console.cloud.google.com → Maps SDK for iOS
    // Clé Google Maps iOS — à renseigner dans .env (GOOGLE_MAPS_API_KEY)
    // Ne jamais committer la vraie clé dans le dépôt public.
    GMSServices.provideAPIKey(Bundle.main.infoDictionary?["GOOGLE_MAPS_IOS_KEY"] as? String ?? "")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
