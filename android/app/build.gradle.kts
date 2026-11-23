import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties").let {
    if (it.exists()) it else rootProject.file("android/key.properties")
}
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.melo.melo_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keyStorePath = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("MELO_KEYSTORE_PATH")
            val keyStorePassword = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("MELO_KEYSTORE_PASSWORD")
            val keyAliasVal = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("MELO_KEY_ALIAS")
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("MELO_KEY_PASSWORD")

            if (keyStorePath != null && keyStorePassword != null && keyAliasVal != null && keyPasswordVal != null) {
                val resolvedFile = file(keyStorePath)
                if (resolvedFile.exists()) {
                    storeFile = resolvedFile
                    storePassword = keyStorePassword
                    keyAlias = keyAliasVal
                    keyPassword = keyPasswordVal
                }
            }
        }
    }

    defaultConfig {
        applicationId = "app.melo.melo_player"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null) {
                signingConfig = releaseSigning
            }
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
