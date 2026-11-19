import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kartikeyamishra.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required for newer notification packages
        isCoreLibraryDesugaringEnabled = true
    }

    // 🚨 ARCHITECT FIX: Updated to modern string assignment to suppress deprecation errors
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.kartikeyamishra.mobile"
        // 🚨 ARCHITECT FIX: Bumped to 26 for 'health' package & added '=' for Kotlin DSL syntax
        minSdk = 26 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Protects against 64k method limit crashes on older devices
        multiDexEnabled = true
    }

    signingConfigs {
        // FIX: the build used to throw when key.properties was missing, which
        // broke every CI build and even local debug builds on a fresh clone.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias") as String
                keyPassword = keystoreProperties.getProperty("keyPassword") as String
                storeFile = file(keystoreProperties.getProperty("storeFile") as String)
                storePassword = keystoreProperties.getProperty("storePassword") as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Unsigned-for-Play fallback so CI can still verify the build.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🚨 FIX: Bumped to 2.1.5 as required by the newest flutter_local_notifications plugin
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
