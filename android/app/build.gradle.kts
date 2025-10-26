import org.gradle.api.JavaVersion

// 1. 'plugins' block
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 2. ⬇️ FIX: key.properties file ko load karne ke liye
val keyPropertiesFile = rootProject.file("android/key.properties")
val keyProperties = java.util.Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    // 3. Aapka original package name (jise workflow badlega)
    namespace = "com.example.chetegram"
    
    // 4. API 35 (jaisa aapne maanga tha)
    compileSdk = 35
    
    // 5. NDK version (pichhle build log se)
    ndkVersion = "27.0.12077973"

    // 6. ⬇️ FIX: Release key ko load karne ka setup
    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = if (keyProperties["storeFile"] != null) file(keyProperties["storeFile"] as String) else null
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 7. Aapka original package name (jise workflow badlega)
        applicationId = "com.example.chetegram"
        
        // 8. Hardcoded values (pichhle 'by extra' error ko fix karne ke liye)
        minSdk = 23
        targetSdk = 35 
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            // 9. ⬇️ FIX: Release build ko 'release' key istemal karne ke liye kehna
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// 10. 'flutter' block (pichhle 'Type Mismatch' error ko fix karne ke liye)
flutter {
    source = "../.."
}
