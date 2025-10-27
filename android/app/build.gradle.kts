import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.opkukna.exambeing"
    compileSdk = 34
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
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.opkukna.exambeing"
        minSdk = 23
        targetSdk = 34
        versionCode = 2
        versionName = "1.0.1"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("release")

            // ⚙️ Add Proguard keep rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation("androidx.credentials:credentials:1.3.0-alpha02")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0-alpha02")
}
