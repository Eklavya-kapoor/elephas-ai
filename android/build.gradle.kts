// android/build.gradle.kts (Project-level build.gradle.kts)
buildscript {
    // Match Kotlin version with the one specified in settings.gradle.kts
    val kotlin_version = "2.1.0" 
    // Match AGP version with the one specified in settings.gradle.kts
    val agp_version = "8.7.3"

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:$agp_version")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// These are your custom build directory configurations. Keep them as is if intentional.
// If you're unsure, you can comment them out to simplify for now.
val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// The commented-out clean task is fine.
// tasks.register<Delete>("clean") {
//     delete(rootProject.layout.buildDirectory)
// }