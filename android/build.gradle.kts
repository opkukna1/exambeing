plugins {
    // 👇 YAHAN CHANGE KIYA HAI (8.3.2 -> 8.9.1)
    id("com.android.application") version "8.9.1" apply false

    // 👇 Kotlin version ko bhi thoda naya kar dete hain (Safety ke liye)
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false

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
