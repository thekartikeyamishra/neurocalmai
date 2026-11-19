import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

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
        create("release") {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("key.properties file not found at ${keystorePropertiesFile.absolutePath}")
            }
            keyAlias = keystoreProperties.getProperty("keyAlias") as String
            keyPassword = keystoreProperties.getProperty("keyPassword") as String
            val storeFilePath = keystoreProperties.getProperty("storeFile") as String
            storeFile = file(storeFilePath)
            storePassword = keystoreProperties.getProperty("storePassword") as String
        }
    }

    buildTypes {
        release {
            // Disabled to prevent JVM Out Of Memory (OOM) crashes on Windows.
            // Flutter AOT compilation natively protects the Dart code.
            isMinifyEnabled = true
            isShrinkResources = true
            
            signingConfig = signingConfigs.getByName("release")
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
