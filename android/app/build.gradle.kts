import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Charger key.properties ──
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// ── Charger local.properties (clés API non commitées) ──
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.allofoods.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.allofoods.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] =
            localProps.getProperty("GOOGLE_MAPS_API_KEY") ?: ""
        // Pas de restriction abiFilters : beaucoup de téléphones d'entrée de
        // gamme au Bénin tournent encore en 32-bit (armeabi-v7a) — un filtre
        // limité à arm64-v8a/x86_64 les empêchait purement et simplement
        // d'installer l'app ("app not installed" / incompatible).
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProps["keyAlias"]     as String
            keyPassword  = keyProps["keyPassword"]  as String
            storeFile    = file(keyProps["storeFile"] as String)
            storePassword = keyProps["storePassword"] as String
            // Forcer v1+v2+v3 explicitement : l'AGP désactive v1 (JAR signing)
            // par défaut dès que minSdk >= 24, mais certains installeurs
            // Android bas de gamme (Tecno/Infinix/itel, très répandus au
            // Bénin) le refusent quand même — "App not installed" sans v1.
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}