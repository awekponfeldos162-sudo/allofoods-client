# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Kotlin coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# local_auth — le R8/ProGuard du build release cassait silencieusement
# l'authentification biométrique sans ces règles (plugin + AndroidX Biometric,
# tous deux basés sur des callbacks/réflexion que le minifieur peut supprimer).
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**
