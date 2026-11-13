import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load release signing keys from key.properties (not committed to git)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

// ── AdMob App ID ──────────────────────────────────────────────────────────────
// lib/core/ads/ad_config.dart is the single source of truth for all three AdMob
// values. The App ID is read from it here so the manifest meta-data can never
// drift from the Dart constants (an App ID that does not match the ad units
// makes every ad request fail).
val adMobConfigFile = file("../../lib/core/ads/ad_config.dart")
val adMobReleaseAppId: String = run {
    // Anchored to the start of a line so a comment that quotes the pattern
    // cannot match first.
    val match = Regex("""(?m)^\s*static const String appId = '([^']+)';""")
        .find(adMobConfigFile.readText())
    val value = match?.groupValues?.get(1)
    if (value == null || !value.startsWith("ca-app-pub-")) {
        throw GradleException(
            "Could not read AdMobConfig.appId (got '${value}') from " +
                "${adMobConfigFile.path}"
        )
    }
    value
}
// Google's public sample App ID — every debug build uses this one so local ad
// and UMP testing works without a real AdMob account.
val adMobTestAppId = "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.inkpebble.randomrecall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.inkpebble.randomrecall"
        minSdk = flutter.minSdkVersion // Firebase Auth requires minSdk 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Overridden per build type below; the default keeps any other variant
        // (e.g. profile) building with the release value.
        manifestPlaceholders["admobAppId"] = adMobReleaseAppId
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Test App ID + AdMobConfig's sample ad units: real ads, no account.
            manifestPlaceholders["admobAppId"] = adMobTestAppId
        }

        release {
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.firebase:firebase-appcheck-debug:17.1.2")
}
