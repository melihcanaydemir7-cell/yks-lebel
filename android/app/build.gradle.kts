import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase's Gradle plugins hard-fail when google-services.json is missing.
// Applying them conditionally keeps `flutter build` working out of the box for
// a fresh clone; drop the real file in android/app/ to enable Analytics and
// Crashlytics. See README "Firebase Setup".
val googleServicesFile = file("google-services.json")
val firebaseEnabled = googleServicesFile.exists()
if (firebaseEnabled) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

// Release signing is read from android/key.properties, which is git-ignored.
// Without it the release build falls back to the debug keystore so that
// `flutter build appbundle` still succeeds locally.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseSigning = keystoreProperties.getProperty("storeFile") != null

// Production AdMob app id comes from the environment (CI secret or local
// shell), never from source control. Falls back to Google's official test id.
val admobAppId: String = System.getenv("ADMOB_ANDROID_APP_ID")
    ?: keystoreProperties.getProperty("admobAppId")
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.example.ykslevel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO(launch): replace with your own reverse-DNS id before publishing.
        applicationId = "com.example.ykslevel"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    // Required by flutter_local_notifications for java.time on older Androids.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
