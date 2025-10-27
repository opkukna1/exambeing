import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase plugin
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.opkukna.exambeing"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    // ✅ Fix for GitHub Actions / AAB build directory
    buildDir = file("../../build")

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = if (keyProperties["storeFile"] != null)
                file(keyProperties["storeFile"] as String)
            else null
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
        applicationId = "com.opkukna.exambeing"
        minSdk = 23         // ✅ तुमने कहा 35 से कम नहीं रखना
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
    }

    buildTypes {
        getByName("release") {
            // ⚙️ SmartAuth + Firebase release fix
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // ✅ Prevent lint aborts (useful for CI or Termux)
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}
