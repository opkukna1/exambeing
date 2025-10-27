// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // 🔧 Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.5.2")

        // 🔥 Google Services (Firebase)
        classpath("com.google.gms:google-services:4.4.2")

        // (Optional) Kotlin Gradle Plugin (for compatibility)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.25")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
