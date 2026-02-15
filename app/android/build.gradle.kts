plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Required for AI Edge SDK (Gemini Nano)
        maven {
            url = uri("https://maven.pkg.github.com/google/generative-ai-android")
            credentials {
                username = "x-access-token"
                password = System.getenv("GITHUB_TOKEN") ?: ""
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
