import org.gradle.api.JavaVersion

// 1. 'plugins' block ko pehle rakhein
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 2. 'gradle.properties' se values lene ka KTS tareeka
val flutterNdkVersion: String by extra
val flutterMinSdkVersion: String by extra
val flutterVersionCode: String by extra
val flutterVersionName: String by extra

android {
    namespace = "com.example.chetegram"
    
    // ⬇️ API Level 35 yahaan set hai
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
        
        // ⬇️ API Level 35 yahaan set hai
        targetSdk = 35 
        
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 3. ⬇️ FIX: 'source' ko 'File' object ke bajaye 'String' path chahiye
flutter {
    source = "../.."
}
