import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.creativeblisslabs.hostelshop"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.creativeblisslabs.hostelshop"

        minSdk = 24
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()

    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(
            FileInputStream(keystorePropertiesFile)
        )
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storePassword = keystoreProperties["storePassword"] as String?

            val stFile =
                keystoreProperties["storeFile"] as String?

            if (stFile != null) {
                storeFile = file(stFile)
            }
        }
    }

    splits {
        abi {
            isEnable = true

            reset()

            include(
                "armeabi-v7a",
                "arm64-v8a",
                "x86",
                "x86_64"
            )

            isUniversalApk = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            ndk {
                debugSymbolLevel = "FULL"
            }

            val relSigning =
                signingConfigs.getByName("release")

            signingConfig =
                if (
                    relSigning.storeFile != null &&
                    relSigning.storeFile!!.exists()
                ) {
                    relSigning
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.0.3"
    )
}

flutter {
    source = "../.."
}