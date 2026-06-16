import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    // Strip UTF-8 BOM if key.properties was saved from PowerShell.
    val raw = keystorePropertiesFile.readText(Charsets.UTF_8).removePrefix("\uFEFF")
    keystoreProperties.load(raw.reader())
}

fun Properties.keystoreProp(key: String): String =
    getProperty(key)?.trim()
        ?: error("Missing or empty '$key' in android/key.properties")

android {
    namespace = "com.mavixas.crickflow"
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
        applicationId = "com.mavixas.crickflow"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.keystoreProp("keyAlias")
                keyPassword = keystoreProperties.keystoreProp("keyPassword")
                storeFile = file(keystoreProperties.keystoreProp("storeFile"))
                storePassword = keystoreProperties.keystoreProp("storePassword")
            }
        }
    }

    packaging {
        resources {
            excludes += "project.clj"
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// rtmp_broadcaster pulls legacy support libraries; keep AndroidX-only classpath.
configurations.configureEach {
    exclude(group = "com.android.support", module = "support-compat")
    exclude(group = "com.android.support", module = "support-core-utils")
    exclude(group = "com.android.support", module = "support-core-ui")
    exclude(group = "com.android.support", module = "support-fragment")
}
