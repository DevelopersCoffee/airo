plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.5.0" apply false
}

// LiteRT-LM (Gemini Nano) lives in a private GitHub Package Registry
// that requires a token with `read:packages`. Real release builds set
// GITHUB_TOKEN in the environment; CI validation builds and default
// clones don't. Publish this flag so `app/build.gradle.kts` can skip
// the `com.google.ai.edge.litertlm:litertlm-android` dependency in
// unauthenticated environments — an unauthenticated fetch would fail
// with `Failed to list versions`, blocking the entire Android build for
// a runtime feature validation builds don't exercise.
val liteRtLmToken: String = System.getenv("GITHUB_TOKEN") ?: ""
val liteRtLmAvailable: Boolean = liteRtLmToken.isNotEmpty()
extra["liteRtLmAvailable"] = liteRtLmAvailable

if (!liteRtLmAvailable) {
    logger.warn(
        "GITHUB_TOKEN is not set — skipping LiteRT-LM Maven repo and " +
            "the com.google.ai.edge.litertlm:litertlm-android dependency. " +
            "Set GITHUB_TOKEN with `read:packages` to enable Gemini Nano.",
    )
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Required for AI Edge SDK (Gemini Nano). Only register the
        // repository when we have a token — Gradle would otherwise
        // still probe it for every dependency in `com.google.ai.edge.litertlm`
        // and fail on unauthenticated 401s.
        if (liteRtLmAvailable) {
            exclusiveContent {
                forRepository {
                    maven {
                        url = uri("https://maven.pkg.github.com/google/generative-ai-android")
                        credentials {
                            username = "x-access-token"
                            password = liteRtLmToken
                        }
                    }
                }
                filter {
                    includeGroup("com.google.ai.edge.litertlm")
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Remove -Werror from Java compilation for third-party plugins that use it
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.removeAll { it == "-Werror" }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
