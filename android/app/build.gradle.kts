plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // ✅ Google Services plugin
}

android {
    namespace = "com.eddycas.quickcalc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.eddycas.quickcalc"
        minSdk = 21
        targetSdk = 34
        versionCode = 2
        versionName = "1.0.0"
    }

    signingConfigs {
        create("release") {
            // These values will come from Codemagic Flutter workflow automatically
            storeFile = file(System.getenv("CM_KEYSTORE_PATH") ?: "")
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("CM_KEY_ALIAS") ?: ""
            keyPassword = System.getenv("CM_KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
