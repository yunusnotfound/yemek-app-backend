import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

// Release signing credentials are read from android/key.properties (never
// committed). If the file is absent (e.g. local dev / CI without secrets),
// the release build falls back to debug signing so the project still builds.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.bitiryemek.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bitiryemek.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] = localProperties.getProperty("MAPBOX_ACCESS_TOKEN", "")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the real release signing config when key.properties is present;
            // otherwise fall back to debug signing so local dev builds / analyze still
            // work. A real release assembly WITHOUT a keystore is blocked by the
            // gradle.taskGraph guard below (no silent debug-signed release ships).
            // See android/key.properties.example for the required fields and the
            // keytool command to generate a keystore.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 code shrinking + resource shrinking for smaller, obfuscated
            // release builds. ProGuard keep rules live in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Sessiz debug-imza fallback'i yalnız yerel/dev derlemeler içindir. Gerçek bir
// release (assemble/bundle/packageRelease) çıktısını debug anahtarıyla imzalayıp
// yayınlamamak için, key.properties yokken release görevini başarısız kıl.
gradle.taskGraph.whenReady {
    val assemblingRelease = allTasks.any { task ->
        val n = task.name
        n.contains("Release") &&
            (n.startsWith("assemble") || n.startsWith("bundle") || n.startsWith("package"))
    }
    if (assemblingRelease && !hasReleaseKeystore) {
        throw GradleException(
            "Release imzası için android/key.properties gerekli — aksi halde build " +
                "debug anahtarıyla imzalanır (Play'e yüklenemez / güvensiz). " +
                "Bkz. android/key.properties.example.",
        )
    }
}

flutter {
    source = "../.."
}
