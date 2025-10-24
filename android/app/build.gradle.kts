import org.gradle.api.JavaVersion
import dev.flutter.plugins.gradle.FlutterExtension

// 'plugins' block (lowercase 'p')
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter se properties padhne ka Kotlin tareeka
val flutterNdkVersion: String by extra
val flutterMinSdkVersion: String by extra
val flutterVersionCode: String by extra
val flutterVersionName: String by extra

android {
    namespace = "com.example.chetegram"
    
    // ⬇️ API Level 35 yahaan set kiya hai
    compileSdk = 35
    
    ndkVersion = flutterNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.chetegram"
        minSdk = flutterMinSdkVersion.toInt()
        
        // ⬇️ API Level 35 yahaan set kiya hai
        targetSdk = 35 
        
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        // 'release' block likhne ka Kotlin tareeka
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 'flutter' block likhne ka Kotlin tareeka
configure<FlutterExtension> {
    source = file("../..")
}
