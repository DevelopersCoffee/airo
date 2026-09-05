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

# llama.cpp GGUF adapter (Pigeon bridge, Kotlin callbacks, and JNI entrypoints)
# must remain discoverable after release shrinking.
-keep class com.write4me.llama_flutter_android.** { *; }
-keep class kotlin.jvm.functions.Function1 { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================
# AI Edge RAG SDK (on-device embeddings / semantic search)
# ============================================
# The SDK's bundled proto classes (EmbedText and friends) reference
# full-protobuf-only marker types -- com.google.protobuf.Internal$ProtoNonnullApi,
# com.google.protobuf.ProtoPresenceBits -- that aren't on the classpath: the
# SDK ships protobuf-lite at runtime and never actually executes the paths
# that touch these annotation-only classes through the single
# EmbeddingRequest/EmbedData/GeckoEmbeddingModel call surface this app uses.
# R8 still fails hard on the reference (its own suggested fix, generated in
# missing_rules.txt, is exactly this -dontwarn pair) because the AAR's
# consumer rules keep the whole proto package regardless of reachability.
-dontwarn com.google.protobuf.Internal$ProtoNonnullApi
-dontwarn com.google.protobuf.ProtoPresenceBits

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
# No blanket keep: every AndroidX artifact ships its own consumer
# proguard-rules.pro (AGP merges these automatically), and androidx is
# the single largest package tree Flutter pulls in -- keeping all of it
# was the main driver of Play Console's low optimization/obfuscation/
# shrinking scores. -dontwarn stays broad since AndroidX has legitimate
# optional-dependency warnings across modules we don't all use.
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

# flutter_local_notifications persists every scheduled notification as JSON and
# reads it back with Gson when the alarm fires:
#
#   ScheduledNotificationReceiver -> gson.fromJson(json, NotificationDetails)
#   FlutterLocalNotificationsPlugin -> new TypeToken<ArrayList<NotificationDetails>>
#
# Gson maps JSON keys onto field *names*, so R8 renaming the fields of
# NotificationDetails silently turns every persisted notification into null
# fields. The plugin ships no consumer rules (checked 22.2.0), and only the
# scheduled path is affected -- `show()` never touches Gson -- so this fails
# exclusively in minified release builds, and only once a scheduled
# notification actually fires. Debug builds and CI tests cannot see it.
#
# Airo schedules from three places:
#   app/lib/features/iptv/epg_reminder_notification_gateway.dart  (EPG reminders)
#   app/lib/features/quest/domain/services/reminder_service.dart  (quest reminders)
#   app/lib/features/agent_chat/data/services/agent_notification_scheduler.dart
#
# RuntimeTypeAdapterFactory resolves the polymorphic style models
# (BigTextStyleInformation and friends) by name, so those must survive too.
# Scoped to what Gson actually reflects over. A blanket `-keep class
# com.dexterous.** { *; }` plus `-keep class com.google.gson.** { *; }` also
# works, but measured +2.09 MB on the phone APK (104,138,751 -> 106,334,207)
# because blanket keeps block shrinking across the dependency graph. Only the
# serialized models and the polymorphic factory need to survive; the receiver
# and plugin classes are manifest-declared, so R8 keeps them as entry points.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { <fields>; }
-keep class com.dexterous.flutterlocalnotifications.RuntimeTypeAdapterFactory { *; }

# Gson resolves generic types through anonymous TypeToken subclasses, which R8
# would otherwise strip. Signature and *Annotation* are already kept above and
# TypeToken needs both. Scoped to the plugin: the only `new TypeToken<...>(){}`
# sites are in ScheduledNotificationReceiver and FlutterLocalNotificationsPlugin.
# A global `-keep class * extends ...TypeToken` works too but makes R8 reason
# over every class in the app.
-keep class com.dexterous.flutterlocalnotifications.** extends com.google.gson.reflect.TypeToken
