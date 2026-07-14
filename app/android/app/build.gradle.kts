import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

fun dartDefine(name: String): String? {
    val encodedDefines = providers.gradleProperty("dart-defines").orNull ?: return null
    return encodedDefines
        .split(",")
        .asSequence()
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded))
            }.getOrNull()
        }
        .firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
}

val appVariant = dartDefine("APP_VARIANT") ?: "full"
val isLeanVariant = appVariant != "full"
val isTvVariant = appVariant == "tv"
val variantApplicationId = when (appVariant) {
    "iptv" -> "io.airo.app.iptv"
    "streaming" -> "io.airo.app.streaming"
    "tv" -> "io.airo.app.tv"
    else -> "io.airo.app"
}
val variantAppLabel = when (appVariant) {
    "iptv" -> "Airo IPTV"
    "streaming" -> "Airo Streaming"
    "tv" -> "Airo TV"
    else -> "Airo"
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hasGoogleServicesConfig = listOf(
    file("google-services.json"),
    file("src/main/google-services.json"),
    file("src/debug/google-services.json"),
    file("src/release/google-services.json"),
).any { config ->
    config.exists() && config.readText().contains("\"package_name\": \"$variantApplicationId\"")
}

if (hasGoogleServicesConfig) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "io.airo.app"
    compileSdk = 36 // Android 16 (API level 36) for current Play target compatibility
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = variantApplicationId
        minSdk = 26 // Android 8.0 - broader device compatibility
        targetSdk = 36 // Target latest Android for Pixel 9
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = variantAppLabel

        // Enable multidex for larger apps
        multiDexEnabled = true

        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    // NOTE: ABI splitting is handled by Flutter's --split-per-abi flag
    // Do NOT add splits.abi here as it conflicts with Flutter's NDK filters
    // See: https://developer.android.com/studio/build/configure-apk-splits

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val signingPropertyNames = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingSigningProperties = signingPropertyNames.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    val hasReleaseSigningConfig = missingSigningProperties.isEmpty()
    val requestedReleaseBuild = gradle.startParameter.taskNames.any { taskName ->
        val normalized = taskName.lowercase()
        normalized.contains("release") || normalized.contains("bundle")
    }
    val isCiBuild = providers.environmentVariable("CI").orNull.equals("true", ignoreCase = true)

    if (!hasReleaseSigningConfig && requestedReleaseBuild && !isCiBuild) {
        throw GradleException(
            "Missing Android release signing properties: ${missingSigningProperties.joinToString()}. " +
                "Copy app/android/key.properties.example to app/android/key.properties " +
                "or configure the GitHub release signing secrets."
        )
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Enable test plugins for debug/test builds
        }
        release {
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Enable code shrinking (R8/ProGuard)
            isMinifyEnabled = true
            // Enable resource shrinking (removes unused resources)
            isShrinkResources = true

            // ProGuard rules for ML Kit, Firebase, and Flutter
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    sourceSets {
        getByName("main") {
            if (isTvVariant) {
                manifest.srcFile("src/tv/AndroidManifest.xml")
                res.srcDir("src/tv/res")
            }
            kotlin.srcDir("src/main/kotlin")
        }
    }

    packaging {
        jniLibs {
            if (isLeanVariant) {
                excludes += setOf(
                    "**/liblitertlm_jni.so",
                    "**/libLiteRt.so",
                    "**/libLiteRtClGlAccelerator.so"
                )
            }
        }
    }

}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    testImplementation("junit:junit:4.13.2")

    // ML Kit GenAI Prompt API for on-device Gemini Nano.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")

    // LiteRT-LM for local on-device LLM inference.
    implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")

    // Coroutines and lifecycle dependencies for async operations
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.11.0")

    // WorkManager and OkHttp for background model downloading
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")

}

flutter {
    source = "../.."
}

tasks.withType<JavaCompile>().configureEach {
    doFirst {
        val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        if (!registrant.exists()) return@doFirst

        val original = registrant.readText()
        val patched = original.replace(
            "new io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin()",
            "new io.flutter.plugins.sharedpreferences.LegacySharedPreferencesPlugin()",
        )
        if (patched != original) {
            registrant.writeText(patched)
        }
    }
}
