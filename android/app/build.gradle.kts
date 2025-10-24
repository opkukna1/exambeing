import org.gradle.api.JavaVersion

// 1. 'plugins' block
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 2. ⬇️ FIX: 'by extra' wali sabhi lines hata di hain, kyonki 
// aapki 'gradle.properties' file mein woh values nahi hain.

android {
    namespace = "com.example.chetegram"
    
    // ⬇️ API Level 35 yahaan set hai
    compileSdk = 35
    
    // ⬇️ FIX: NDK version seedhe (hardcode) likh diya hai
    ndkVersion = "25.1.8937393" // (Standard Flutter NDK version)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.chetegram"
        
        // ⬇️ FIX: Baaki values bhi seedhe (hardcode) likh di hain
        minSdk = 21 
        targetSdk = 35 // API 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 3. 'flutter' block 
flutter {
    source = "../.."
}
