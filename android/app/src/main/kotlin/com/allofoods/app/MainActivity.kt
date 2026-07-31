package com.allofoods.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (pas FlutterActivity) — requis par local_auth
// pour afficher le prompt d'authentification biométrique Android.
class MainActivity : FlutterFragmentActivity()
