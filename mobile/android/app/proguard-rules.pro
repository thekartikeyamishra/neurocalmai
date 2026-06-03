# ==========================================
# NEUROCALM AI: PROGUARD & R8 RULES
# ==========================================

# 1. THE FIX: Ignore missing Google Play Core classes (Flutter Engine)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 2. FLUTTER CORE
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class plugins.flutter.io.** { *; }

# 3. GOOGLE ADMOB
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# 4. FIREBASE CORE
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.auth.** { *; }

# 5. DIO (Network Layer)
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# 6. ML KIT (Emotion Scanner)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**