buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Add Google Services versioned plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}

plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
    // ❌ यहां version मत दो, वरना conflict होगा
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
