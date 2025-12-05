plugins {
    // 👇 YAHAN VERSION LIKHNA JARURI HAI (Gradle 8.4 ke liye 8.3.2 best hai)
    id("com.android.application") version "8.3.2" apply false

    // 👇 Kotlin ka version bhi batana padega
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false

    id("dev.flutter.flutter-gradle-plugin") apply false
    
    // 👇 Ye aapne sahi likha tha
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
