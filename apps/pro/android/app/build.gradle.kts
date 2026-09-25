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
    namespace = "com.moncar.moncar_pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant Play Store — définitif après la première publication.
        applicationId = "com.moncar.moncar_pro"
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
            manifestPlaceholders["appName"] = "MON CAR PRO Dev"
        }
        create("recette") {
            dimension = "env"
            manifestPlaceholders["appName"] = "MON CAR PRO Recette"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "MON CAR PRO"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
