import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadProperties(file: File) = Properties().apply { file.inputStream().use { load(it) } }

// android/key.properties (gitignored) names a file holding the signing details,
// so passwords stay in one place outside this project. Without it, release
// builds use the debug key.
val keyProperties = rootProject.file("key.properties")
val signing = if (keyProperties.exists()) {
    loadProperties(file(loadProperties(keyProperties).getProperty("signingFile")))
} else {
    null
}

android {
    namespace = "io.max.paperplay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Compresses native libraries in the APK, for a much smaller file to share.
    // Android unpacks them on install, so the installed app takes more space.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.max.paperplay"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signing != null) {
            create("release") {
                storeFile = file(signing.getProperty("keystore.path"))
                storePassword = signing.getProperty("keystore.password")
                keyAlias = signing.getProperty("key.alias")
                keyPassword = signing.getProperty("key.password")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (signing != null) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
