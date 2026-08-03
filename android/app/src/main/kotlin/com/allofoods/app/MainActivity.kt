package com.allofoods.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (pas FlutterActivity) — requis par local_auth
// pour afficher le prompt d'authentification biométrique Android.
class MainActivity : FlutterFragmentActivity() {
    private val secureScreenChannel = "com.allofoods.app/secure_screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // FLAG_SECURE — empêche captures d'écran/enregistrement pendant le
        // paiement (numéro Mobile Money, montants) ; activé/désactivé à la
        // demande de PaiementPage via secure_screen_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureScreenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
