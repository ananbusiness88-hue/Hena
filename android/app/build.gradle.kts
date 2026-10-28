import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { input ->
        keystoreProperties.load(input)
    }
}

// A release build must be signed with the upload key. Reading the values with
// a hard cast produced a confusing NullCastException whenever key.properties
// was missing (fresh clone, CI runner, new machine), so the requirements are
// validated explicitly and the build fails with an actionable message instead.
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val hasReleaseSigning = releaseStoreFilePath != null &&
    rootProject.file(releaseStoreFilePath).exists()

if (isReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured.\n" +
        "Expected android/key.properties containing storeFile, keyAlias, " +
        "keyPassword and storePassword, plus the keystore file it points to.\n" +
        "That file is intentionally not committed (see .gitignore): provide it " +
        "from your CI secret store or copy it from a secure location."
    )
}
android {
    namespace = "com.hena.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.hena.app"
        // The SDK levels deliberately track the Flutter SDK defaults
        // (compileSdk 36 / targetSdk 36 / minSdk 24): Google Play requires
        // targeting the latest stable platform version, and Flutter updates
        // those defaults on every stable release.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }

            // إعدادات ضغط وتقليص حجم التطبيق وحذف الكود الزائد
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
