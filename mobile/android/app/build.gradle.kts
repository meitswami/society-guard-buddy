import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (local) or the same values written by CI from secrets.
//   storeFile=/abs/path/upload-keystore.jks
//   storePassword=…
//   keyAlias=upload
//   keyPassword=…
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile")?.let { file(it).exists() } == true

// Play Store package name. To replace the existing AppMySite listing this MUST equal that
// app's package name — set it with `-PappId=com.example.app` (CI: ANDROID_APPLICATION_ID).
val appId: String = (project.findProperty("appId") as String?)
    ?: System.getenv("ANDROID_APPLICATION_ID")?.takeIf { it.isNotBlank() }
    ?: "app.kutumbika.kutumbika_mobile"

android {
    // Kotlin package of MainActivity — independent of the Play Store applicationId.
    namespace = "app.kutumbika.kutumbika_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = appId
        // ML Kit face detection, camera and speech need API 24+ (Android 7).
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Set from pubspec `version:` or `flutter build … --build-number/--build-name` (CI).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Kutumbika"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without a keystore (local dev) fall back to debug keys so `flutter run --release` works.
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Apply when google-services.json is present (Firebase phone OTP + FCM push).
// CI writes it from the GOOGLE_SERVICES_JSON secret. See docs/mobile/FIREBASE-NATIVE-SETUP.md.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
