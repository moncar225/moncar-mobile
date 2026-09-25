import java.io.FileInputStream
import java.util.Properties

// Signature release : android/key.properties (jamais commité, voir
// android/key.properties.example).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.moncar.moncar_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant Play Store — définitif après la première publication.
        applicationId = "com.moncar.moncar_client"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Environnements de compilation (roadmap Sprint 1) : `--flavor dev|recette|prod`
    // + `--dart-define-from-file=../../config/<env>.json` (URL d'API, Sentry).
    // Même applicationId pour les trois : la config Firebase (google-services.json)
    // ne connaît que celui-ci. Les trois variantes ne coexistent donc pas sur
    // un même téléphone ; seul le nom affiché change.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            isDefault = true
            manifestPlaceholders["appName"] = "MON CAR Dev"
        }
        create("recette") {
            dimension = "env"
            manifestPlaceholders["appName"] = "MON CAR Recette"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "MON CAR"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sans key.properties (poste de dev), on retombe sur la clé debug
            // pour que `flutter run --release` fonctionne ; un tel APK/AAB
            // n'est PAS publiable sur le Play Store.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
