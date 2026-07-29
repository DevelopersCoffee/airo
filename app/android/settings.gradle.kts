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
    // 9.3.0 was reverted for the same reason in 249ad2eb (#1011); 9.3.1
    // reintroduced it via #1336. See #1348.
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")
