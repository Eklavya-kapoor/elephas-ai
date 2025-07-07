// ===== android/app/build.gradle.kts =====
// (Replace your entire android/app/build.gradle.kts with this)

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.scamshield_flutter_app"
    compileSdk = 35 // Keep as is, or update to 34 if that's your targetSdk
    ndkVersion = "27.0.12077973" // Keep as is

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // Changed from VERSION_11
        targetCompatibility = JavaVersion.VERSION_17 // Changed from VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString() // Changed from VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.scamshield_flutter_app"
        minSdk = 21
        targetSdk = 35 // Keep as is
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    packaging {
        resources {
            pickFirsts += listOf(
                "**/libc++_shared.so",
                "**/libjsc.so"
            )
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }
    }
}

dependencies {
    // Core dependencies
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // ML Kit for text recognition from screenshots
    implementation("com.google.mlkit:text-recognition:16.0.0")
    
    // AndroidX dependencies for UI and services
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // Lifecycle components for service management
    implementation("androidx.lifecycle:lifecycle-process:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    
    // Coroutines for asynchronous operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter {
    source = "../.."
}