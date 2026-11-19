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
-dontwarn com.google.mlkit.**# ==========================================
# NEUROCALM AI: OPTIMIZED PROGUARD & R8 RULES
# ==========================================

# 1. Google Play Core & Deferred Components
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 2. Flutter Embedding & Plugins (Preserve JNI entrypoints only)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }

# 3. Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { public *; }
-keep class com.google.ads.** { public *; }
-dontwarn com.google.android.gms.ads.**

# 4. Firebase & Google APIs
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# 5. ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# 6. Desugaring / Java 8+ APIs
-dontwarn java.time.**