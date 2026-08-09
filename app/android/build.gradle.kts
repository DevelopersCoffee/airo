plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.5.0" apply false
}

// LiteRT-LM is published on Google's public Maven repository. Keep a
// switch for deterministic stub builds, but use the real backend by default.
val liteRtLmAvailable: Boolean = System.getenv("AIRO_USE_LITERT_STUB") != "true"
extra["liteRtLmAvailable"] = liteRtLmAvailable

if (!liteRtLmAvailable) {
    logger.warn("AIRO_USE_LITERT_STUB=true — using the LiteRT-LM stub backend.")
}

// Same mechanism, a different dependency: the AI Edge RAG SDK
// (embeddings, semantic search -- see
// docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md). A
// separate flag rather than reusing liteRtLmAvailable: this is a distinct
// Gradle dependency and a distinct native plugin, and toggling one must not
// silently toggle the other.
val embeddingAvailable: Boolean = System.getenv("AIRO_USE_EMBEDDING_STUB") != "true"
extra["embeddingAvailable"] = embeddingAvailable

if (!embeddingAvailable) {
    logger.warn("AIRO_USE_EMBEDDING_STUB=true — using the embedding stub backend.")
}

allprojects {
    repositories {
        google()
        mavenCentral()
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
