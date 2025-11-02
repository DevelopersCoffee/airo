plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.airo.superapp"
    compileSdk = 36 // Android 15 (API level 35) for Pixel 9 compatibility
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.airo.superapp"
        minSdk = 31 // Required for Gemini Nano AI Core library
        targetSdk = 36 // Target latest Android for Pixel 9
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for larger apps
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            kotlin.srcDir("src/main/kotlin")
        }
    }

    // Gemini Nano dependencies - Currently Parked
    // TODO: Re-enable when resuming Gemini Nano integration
    // dependencies {
    //     implementation("com.google.mlkit:genai-summarization:1.0.0-beta1")
    //     implementation("com.google.mlkit:genai-image-description:1.0.0-beta1")
    //     implementation("com.google.mlkit:genai-proofreading:1.0.0-beta1")
    //     implementation("com.google.mlkit:genai-rewriting:1.0.0-beta1")
    //     runtimeOnly("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    //     implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    // }
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
