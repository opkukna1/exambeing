import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// key.properties load karne ka code (Same as yours)
val keyPropertiesFile = rootProject.file("key.properties") 
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.opkukna.exambeing"
    compileSdk = 36 // ✅ Apka purana version (No Change)
    ndkVersion = "27.0.12077973" 

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
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.opkukna.exambeing"
        minSdk = 23
        targetSdk = 36 // ✅ Apka purana version (No Change)
        versionCode = 5
        versionName = "1.0.4"
    }

    buildTypes {
        getByName("release") {
            // ⬇️===== SIRF YE CHANGES KIYE HAIN (Warning Hatane Ke Liye) =====⬇️
            
            // 1. Minify ON kiya (Warning hatane ke liye zaroori)
            isMinifyEnabled = true 
            
            // 2. Shrink ON kiya (Size kam karne ke liye)
            isShrinkResources = true 
            
            // 3. Proguard Rules add kiye (Crash se bachne ke liye)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // 4. Debug Symbols Full kiye (Play Console Warning Fix)
            ndk {
                debugSymbolLevel = "FULL"
            }
            
            // ⬆️=============================================================⬆️
            
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
