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

/// Every ABI an Android artifact in this project can carry.
val ALL_ANDROID_ABIS = listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")

/// The one ABI this build targets, or null when it targets several.
///
/// Flutter passes its `--target-platform` values through the `target-platform`
/// Gradle property; `--split-per-abi` passes all of them.
val singleAbi: String? =
    (providers.gradleProperty("target-platform").orNull ?: "")
        .split(",")
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .singleOrNull()
        ?.let { platform ->
            when (platform) {
                "android-arm64" -> "arm64-v8a"
                "android-arm" -> "armeabi-v7a"
                "android-x64" -> "x86_64"
                "android-x86" -> "x86"
                else -> null
            }
        }

val appVariant = dartDefine("APP_VARIANT") ?: "full"
val isLeanVariant = appVariant != "full"
val isTvVariant = appVariant == "tv"
val isCoinsVariant = appVariant == "coins"
val variantApplicationId = when (appVariant) {
    "tv" -> "io.airo.app.tv"
    "coins" -> "io.airo.app.coins"
    else -> "io.airo.app"
}
val variantAppLabel = when (appVariant) {
    "tv" -> "Airo TV"
    "coins" -> "Airo Coins"
    else -> "Airo"
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
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
    val allowDebugReleaseSigning = providers.environmentVariable(
        "AIRO_ALLOW_DEBUG_RELEASE_SIGNING",
    ).orNull.equals("true", ignoreCase = true)

    if (
        !hasReleaseSigningConfig &&
        requestedReleaseBuild &&
        !isCiBuild &&
        !allowDebugReleaseSigning
    ) {
        throw GradleException(
            "Missing Android release signing properties: ${missingSigningProperties.joinToString()}. " +
                "Copy app/android/key.properties.example to app/android/key.properties " +
                "or configure the GitHub release signing secrets. For a local, " +
                "non-distributable size qualification build only, set " +
                "AIRO_ALLOW_DEBUG_RELEASE_SIGNING=true."
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
            if (isCoinsVariant) {
                manifest.srcFile("src/coins/AndroidManifest.xml")
                kotlin.setSrcDirs(listOf("src/coins/kotlin"))
            } else {
                kotlin.setSrcDirs(listOf("src/product/kotlin"))
            }
            // Pick the real LiteRT-LM plugin only when the private Maven
            // dependency was resolvable (see `app/android/build.gradle.kts`).
            // Otherwise compile a stub with the same class name that
            // reports the feature as unavailable so the rest of the
            // Kotlin source (MainActivity + MethodChannel wiring) still
            // compiles without the com.google.ai.edge.litertlm.* imports.
            val liteRtLmAvailable =
                rootProject.extra.get("liteRtLmAvailable") as Boolean
            if (!isCoinsVariant) {
                kotlin.srcDir(
                    if (liteRtLmAvailable) "src/withLitertlm/kotlin"
                    else "src/withoutLitertlm/kotlin",
                )
            }
        }
    }

    packaging {
        jniLibs {
            // Flutter's --target-platform filters only the libs Flutter itself
            // contributes (libflutter.so, libapp.so). Native libs that arrive
            // inside a plugin AAR keep every ABI they were published with, so a
            // single-ABI build still ships the others as dead weight -- 2.9 MB
            // of x86_64 and armeabi-v7a libsqlite3.so in the arm64-only TV APK.
            //
            // Drop them when the build declares exactly one ABI. A
            // --split-per-abi build passes every platform, so singleAbi is null
            // there and nothing is excluded; ABI splitting stays Flutter's job
            // (see the splits.abi note above).
            singleAbi?.let { abi ->
                for (other in ALL_ANDROID_ABIS.filter { it != abi }) {
                    excludes += "lib/$other/**"
                }
            }
            if (isLeanVariant) {
                excludes += setOf(
                    "**/liblitertlm_jni.so",
                    "**/libLiteRt.so",
                    "**/libLiteRtClGlAccelerator.so"
                )
            }
            // CV-030: mpv/media_kit native libs are excluded from variants
            // whose shipping matrix uses video_player as the sole engine.
            // - TV: storage-starved boxes (~8 GB); videoPlayer only per design.
            // - TV: allowedNativePlugins declares video_player only; mpv
            //   arrives transitively but is not intended to run. Stripping
            //   native libraries keeps the APK inside its 35 MB budget.
            // A codec failure yields a clean typed error, not a fallback.
            if (isTvVariant) {
                excludes += setOf(
                    "**/libmpv.so",
                    "**/libplayer.so",
                    "**/libavcodec.so",
                    "**/libavformat.so",
                    "**/libavutil.so",
                    "**/libavdevice.so",
                    "**/libavfilter.so",
                    "**/libswresample.so",
                    "**/libswscale.so",
                    "**/libmediakitandroidhelper.so"
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
    if (!isCoinsVariant) {
        implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")
    }

    // LiteRT-LM for local on-device LLM inference. The artifact is published
    // on Google's public Maven repository and is enabled by default; set
    // AIRO_USE_LITERT_STUB=true for a dependency-free validation build.
    //
    // Pinned explicitly — do NOT use `latest.release`. Floating versions
    // caused issue #860 (silent CI break for ~10 days on a Backend/close API
    // shift in 0.14.0). LiteRtLmPlugin.kt has been verified against the 0.14.0
    // Kotlin API surface (Backend.CPU/GPU/NPU factories, engine.close(),
    // Contents.of, ConversationConfig) per developers.google.com/edge/litert-lm.
    if (!isCoinsVariant && rootProject.extra.get("liteRtLmAvailable") as Boolean) {
        implementation("com.google.ai.edge.litertlm:litertlm-android:0.15.0")
    }

    if (!isCoinsVariant) {
        // Coroutines and lifecycle dependencies for async operations
        implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.0")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.11.0")

        implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    }

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
