# ============================================
# ProGuard Rules for Airo Super App
# ============================================

# ============================================
# Flutter Core Rules
# ============================================
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }

# Keep Flutter plugins
-keep class io.flutter.plugins.** { *; }

# ============================================
# Google ML Kit (Gemini Nano)
# ============================================
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep GenAI Prompt API
-keep class com.google.mlkit.genai.** { *; }

# ============================================
# Firebase
# ============================================
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ============================================
# Google Play Services
# ============================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ============================================
# Kotlin Coroutines
# ============================================
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ============================================
# AndroidX / Jetpack
# ============================================
-keep class androidx.** { *; }
-dontwarn androidx.**

# Lifecycle
-keep class androidx.lifecycle.** { *; }
-keepclassmembers class * implements androidx.lifecycle.LifecycleObserver {
    <init>(...);
}

# ============================================
# Stockfish Chess Engine (JNI)
# ============================================
-keep class com.example.stockfish.** { *; }
-keep class stockfish.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================
# Audio Players (just_audio, audioplayers)
# ============================================
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ============================================
# Video Player
# ============================================
-keep class com.google.android.exoplayer.** { *; }
-dontwarn com.google.android.exoplayer.**

# ============================================
# Flame Game Engine
# ============================================
-keep class org.libsdl.** { *; }
-dontwarn org.libsdl.**

# ============================================
# SQLite / Drift Database
# ============================================
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ============================================
# Serialization (JSON)
# ============================================
# Keep classes used for JSON serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# ============================================
# Reflection (for plugins that use reflection)
# ============================================
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ============================================
# Debugging (optional - remove for smaller APK)
# ============================================
# Keep line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
# Hide original source file name
-renamesourcefileattribute SourceFile

# ============================================
# Optimization Settings
# ============================================
# Don't optimize too aggressively
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
