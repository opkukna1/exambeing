plugins {
    // 👇 Android Plugin (System ne 8.9.1 manga tha)
    id("com.android.application") version "8.9.1" apply false

    // 👇 KOTLIN FIX: Yahan 1.9.24 ko hatakar 2.1.0 kar diya hai
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false

    id("dev.flutter.flutter-gradle-plugin") apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
