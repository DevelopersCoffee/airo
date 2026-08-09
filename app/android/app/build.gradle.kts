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
val isTvVariant = appVariant == "tv"
val isCoinsVariant = appVariant == "coins"
val isMindVariant = appVariant == "mind"
val variantApplicationId = when (appVariant) {
    "tv" -> "io.airo.app.tv"
    "coins" -> "io.airo.app.coins"
    "mind" -> "io.airo.app.mind"
    else -> "io.airo.app"
}
val variantAppLabel = when (appVariant) {
    "tv" -> "Airo TV"
    "coins" -> "Airo Coins"
    "mind" -> "Airo Mind"
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
    // Sourced from gradle/libs.versions.toml (airo-compile-sdk). Package
    // Android modules must stay at or above this baseline — see #1575 and
    // scripts/check-android-sdk-baseline.sh.
    compileSdk = libs.versions.airo.compile.sdk.get().toInt()
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    lint {
        // AGP 9.3.1's own lint-analysis engine crashes with a NoSuchMethodError
        // in its JavaDoc/UAST parser while reading Flutter-plugin Java sources
        // (url_launcher_android's UrlLauncher.java is the confirmed trigger).
        // This is an upstream AGP bug, not anything in this repo's code --
        // and it is not specific to the automatic lintVitalAnalyzeRelease
        // pre-flight: an explicit `./gradlew lintRelease` run with correct
        // -Ptarget/-Pdart-defines hit the identical crash (confirmed against
        // CI logs, not assumed), so no lint task at all currently completes
        // against this dependency graph.
        //
        // checkReleaseBuilds=false unhooks the crashing pre-flight from
        // assembleRelease/bundleRelease so release builds are not blocked.
        // This is a real, deliberate coverage gap, not a redundant duplicate
        // being removed -- there is currently NO working Android-native lint
        // gate anywhere in this repo (the separate `lint:` CI job in ci.yml
        // is also a dead stub; see #1533). Restoring coverage
        // needs a fix at the AGP/lint-engine-version layer -- e.g. pinning
        // an older lint via android.experimental.lint.version, or downgrading
        // AGP below 9.3 -- neither of which has been attempted yet.
        checkReleaseBuilds = false
    }

    defaultConfig {
        applicationId = variantApplicationId
        minSdk = libs.versions.airo.min.sdk.get().toInt()
        targetSdk = libs.versions.airo.target.sdk.get().toInt()
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
            if (isMindVariant) {
                // Mind reuses the product MainActivity (it extends
                // AudioServiceFragmentActivity and pubspec_mind.yaml keeps
                // audio_service real), so there is no `src/mind/kotlin`. The
                // variant manifest only exists to drop the IPTV deep links and
                // picture-in-picture the full app declares -- io.airo.app.mind
                // must not claim `airo://iptv` or the /airo/iptv app link.
                manifest.srcFile("src/mind/AndroidManifest.xml")
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
            // Same mechanism as LiteRT-LM above, a separate flag and a
            // separate plugin (embeddings/semantic search -- see
            // docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md).
            // Excluded from Coins entirely for the same reason LiteRT-LM is:
            // Coins compiles its own `src/coins/kotlin` MainActivity that
            // never references EmbeddingPlugin. TV shares `src/product/kotlin`
            // with Mind and full (MainActivity registers EmbeddingPlugin
            // unconditionally there), so TV still needs the stub compiled --
            // it just must never get the real SDK. Unlike LiteRT-LM, the AI
            // Edge RAG SDK's bundled protobuf classes fail R8 minification
            // with "missing classes" (com.google.protobuf.Internal$ProtoNonnullApi)
            // when nothing in the TV variant reaches them, so its Gradle
            // dependency (below) cannot stay on TV's classpath the way
            // LiteRT-LM's does; the stub keeps TV compiling without it.
            val embeddingAvailable =
                rootProject.extra.get("embeddingAvailable") as Boolean && !isTvVariant
            if (!isCoinsVariant) {
                kotlin.srcDir(
                    if (embeddingAvailable) "src/withEmbedding/kotlin"
                    else "src/withoutEmbedding/kotlin",
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
            // TV and Coins never reach a local-LLM code path, so their
            // LiteRT-LM natives are unreachable weight -- TV keeps the Gradle
            // dependency on the classpath without the .so and is fine, because
            // nothing in that product calls it. Mind is lean too, but its
            // assistant surface drives the on-device model manager as a
            // first-class feature, so it is the one lean variant that must
            // keep the libraries.
            if (isTvVariant || isCoinsVariant) {
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

    // AI Edge RAG SDK, for on-device text embeddings (semantic search --
    // docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md). A
    // separate dependency from LiteRT-LM above: different Gradle coordinate,
    // different native API (GeckoEmbeddingModel/Embedder<String>, not
    // Engine/Conversation). Pinned explicitly, same reasoning as LiteRT-LM's
    // pin above — see this file's LiteRT-LM comment for the incident that
    // pin exists to prevent.
    //
    // Excluded from TV as well as Coins, unlike LiteRT-LM: this SDK's bundled
    // protobuf classes (com.google.ai.edge.localagents.rag.models.proto.*)
    // fail R8 minification with "missing classes" on TV, where nothing
    // reaches them, because the SDK doesn't ship its own protobuf runtime.
    // LiteRT-LM's dependency has no such gap and can stay on TV's classpath
    // unused; this one cannot.
    if (!isCoinsVariant && !isTvVariant && rootProject.extra.get("embeddingAvailable") as Boolean) {
        implementation("com.google.ai.edge.localagents:localagents-rag:0.1.0")
        implementation("com.google.mediapipe:tasks-genai:0.10.22")
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
