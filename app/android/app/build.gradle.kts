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

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "io.airo.app"
    compileSdk = 36 // Android 15 (API level 35) for Pixel 9 compatibility
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
        applicationId = "io.airo.app"
        minSdk = 26 // Android 8.0 - broader device compatibility
        targetSdk = 36 // Target latest Android for Pixel 9
        versionCode = flutter.versionCode
        versionName = flutter.versionName

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

    // ML Kit GenAI Prompt API for on-device Gemini Nano.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta1")

    // LiteRT-LM for local on-device LLM inference.
    implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")

    // Coroutines and lifecycle dependencies for async operations
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")

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
