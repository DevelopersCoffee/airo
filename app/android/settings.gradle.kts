pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned to 9.2.1: AGP 9.3.x crashes lint's CommentDetector with
    // NoSuchMethodError: JavaDocParser.parseDataItem during
    // lintVitalAnalyzeRelease, which fails every release assembly.
    // Reverted three times now: 9.3.0 in 249ad2eb (#1011), 9.3.1 via
    // #1336, and again when Dependabot PR #1349 -- opened before the
    // ignore rule below existed -- was merged on 2026-07-29 and silently
    // undid the pin while leaving this comment in place. Check the version
    // on the next line, not this comment, before believing either.
    // See #1348.
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

// Repository Android SDK baseline lives at ../../gradle/libs.versions.toml so
// package modules and CI share one authority (#1575). The path is relative to
// this settings file (app/android/).
dependencyResolutionManagement {
    // Keep existing per-project repositories (Flutter plugins + allprojects).
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    versionCatalogs {
        create("libs") {
            from(files("../../gradle/libs.versions.toml"))
        }
    }
}

include(":app")
