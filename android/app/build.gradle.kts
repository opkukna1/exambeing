import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// key.properties load karne ka code
val keyPropertiesFile = rootProject.file("key.properties") 
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.opkukna.exambeing"
    compileSdk = 36
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
        targetSdk = 36
        versionCode = 15
        versionName = "1.0.14"
    }

    buildTypes {
        getByName("release") {
            // Warning aur Size ke liye ye sab TRUE rahenge
            isMinifyEnabled = true 
            isShrinkResources = true 
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            ndk {
                debugSymbolLevel = "FULL"
            }
            
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Notification ke liye
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ⬇️===== YEH LINE ADD KI HAI (R8 Error Fix ke liye) =====⬇️
    implementation("com.google.android.gms:play-services-auth:21.0.0")
    // ⬆️=====================================================⬆️
}
