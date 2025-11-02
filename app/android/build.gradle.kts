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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
